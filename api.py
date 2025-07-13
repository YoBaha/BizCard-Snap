from flask import Flask, request, jsonify
from flask_jwt_extended import JWTManager, jwt_required, create_access_token, get_jwt_identity
from werkzeug.security import generate_password_hash, check_password_hash
from pymongo import MongoClient
from PIL import Image
import numpy as np
import easyocr
from gliner import GLiNER
import os
from pathlib import Path
from dotenv import load_dotenv
import re
import pandas as pd
import cv2
import random  
import smtplib  
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import datetime, timedelta


load_dotenv()

# Set environment variables
os.environ['GLINER_HOME'] = str(Path.home() / '.gliner_models')
os.environ['TRANSFORMERS_CACHE'] = str(Path.home() / '.gliner_models' / 'cache')

# Initialize Flask app and JWT
app = Flask(__name__)
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'default-insecure-key')
jwt = JWTManager(app)

# MongoDB setup
mongo_uri = os.getenv('MONGO_URI')
if not mongo_uri:
    raise ValueError("MONGO_URI not set in .env file")
client = MongoClient(mongo_uri)
db = client['business_cards']
users_collection = db['users']
cards_collection = db['cards']
reset_codes_collection = db['reset_codes']
reset_codes_collection.create_index("expires_at", expireAfterSeconds=0)


# Email configuration
EMAIL_ADDRESS = os.getenv('EMAIL_ADDRESS')
EMAIL_PASSWORD = os.getenv('EMAIL_PASSWORD')
SMTP_SERVER = os.getenv('SMTP_SERVER', 'smtp.gmail.com')
SMTP_PORT = int(os.getenv('SMTP_PORT', 587))

# Initialize EasyOCR reader
reader = easyocr.Reader(['en'])

def get_model_path():
    base_dir = Path.home() / '.gliner_models'
    model_dir = base_dir / 'gliner_large-v2.1'
    return model_dir

def load_gliner_model():
    model_dir = get_model_path()
    if not model_dir.exists():
        model = GLiNER.from_pretrained("urchade/gliner_large-v2.1")
        model_dir.parent.mkdir(parents=True, exist_ok=True)
        model.save_pretrained(str(model_dir))
    return GLiNER.from_pretrained(str(model_dir))

def extract_text_from_image(image):
    image_array = np.array(image)
    return reader.readtext(image_array, detail=0, paragraph=True)

def extract_qr_code(image):
    # Convert PIL Image to OpenCV format
    open_cv_image = np.array(image)
    open_cv_image = open_cv_image[:, :, ::-1].copy()  # Convert RGB to BGR
    # Detect QR code
    qr_code_detector = cv2.QRCodeDetector()
    retval, decoded_info, points, _ = qr_code_detector.detectAndDecodeMulti(open_cv_image)
    if retval and decoded_info:
        return decoded_info[0] if decoded_info else None  # Return the first detected QR code
    return None

def process_entities(text, model, threshold=0.3, nested_ner=True):
    labels = "person name, company name, job title, phone, email, address"
    labels = [label.strip() for label in labels.split(",")]
    entities = model.predict_entities(text, labels, flat_ner=not nested_ner, threshold=threshold)
    results = {
        "Person Name": [], "Company Name": [], "Job Title": [], "Phone": [], "Email": [], "Address": []
    }
    
    print(f"Processing text: '{text}'")
    
    for entity in entities:
        category = entity["label"].title()
        if category in results:
            results[category].append(entity["text"])

    phone_pattern = r'\+?\d{1,3}\s?\d{6,15}'
    phone_numbers = re.findall(phone_pattern, text)
    print(f"Regex matches for phone: {phone_numbers}")
    if phone_numbers:
        results["Phone"].extend(phone_numbers)

    return {k: "; ".join(set(v)) if v else "" for k, v in results.items()}

model = load_gliner_model()

@app.route('/signup', methods=['POST'])
def signup():
    data = request.get_json()
    username = data.get('username')
    email = data.get('email')
    password = data.get('password')

    if not username or not email or not password:
        return jsonify({"error": "Missing required fields"}), 400

    if users_collection.find_one({"username": username}):
        return jsonify({"error": "Username already exists"}), 400

    hashed_password = generate_password_hash(password)
    user_data = {"username": username, "email": email, "password": hashed_password}
    users_collection.insert_one(user_data)
    return jsonify({"message": "User created successfully", "username": username}), 201

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    user = users_collection.find_one({"username": username})
    if not user or not check_password_hash(user['password'], password):
        return jsonify({"success": False, "message": "Invalid credentials"}), 401

    access_token = create_access_token(identity=username, expires_delta=timedelta(days=30))
    return jsonify({"success": True, "message": "Login successful", "access_token": access_token}), 200

@app.route('/validate-token', methods=['GET'])
@jwt_required()
def validate_token():
    current_user = get_jwt_identity()
    return jsonify({"success": True, "message": "Token is valid", "username": current_user}), 200

#_________________________________________________________
def send_reset_email(email, code):
    try:
        msg = MIMEMultipart()
        msg['Subject'] = 'BizCard Snap Password Reset'
        msg['From'] = EMAIL_ADDRESS
        msg['To'] = email

        html = f"""
        <html>
            <body>
                <h2>BizCard Snap Password Reset</h2>
                <p>Your password reset code is: <strong>{code}</strong></p>
                <p>This code will expire in 10 minutes.</p>
                <p>If you did not request a password reset, please ignore this email.</p>
            </body>
        </html>
        """
        msg.attach(MIMEText(html, 'html'))

        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(EMAIL_ADDRESS, EMAIL_PASSWORD)
            server.sendmail(EMAIL_ADDRESS, email, msg.as_string())
        return True
    except smtplib.SMTPAuthenticationError:
        print("SMTP Authentication failed.")
        return False
    except smtplib.SMTPException as e:
        print(f"SMTP error: {e}")
        return False
    except Exception as e:
        print(f"Unexpected error: {e}")
        return False

@app.route('/send-reset-code', methods=['POST'])
def send_reset_code():
    data = request.get_json()
    email = data.get('email')
    if not email:
        return jsonify({"success": False, "message": "Email is required"}), 400

    user = users_collection.find_one({"email": email})
    if not user:
        return jsonify({"success": False, "message": "Email not found"}), 404

    # Generate 4-digit code
    code = str(random.randint(1000, 9999))
    expires_at = datetime.utcnow() + timedelta(minutes=10)

    # Store code in reset_codes_collection
    reset_codes_collection.delete_many({"email": email}) 
    reset_codes_collection.insert_one({
        "email": email,
        "code": code,
        "expires_at": expires_at
    })

    # Send email
    if send_reset_email(email, code):
        return jsonify({"success": True, "message": "Reset code sent to email"}), 200
    else:
        return jsonify({"success": False, "message": "Failed to send email"}), 500

@app.route('/verify-reset-code', methods=['POST'])
def verify_reset_code():
    data = request.get_json()
    email = data.get('email')
    code = data.get('code')
    if not email or not code:
        return jsonify({"success": False, "message": "Email and code are required"}), 400

    reset_code = reset_codes_collection.find_one({"email": email})
    if not reset_code:
        return jsonify({"success": False, "message": "No reset code found"}), 404

    if reset_code['code'] != code:
        return jsonify({"success": False, "message": "Invalid code"}), 400

    if datetime.utcnow() > reset_code['expires_at']:
        reset_codes_collection.delete_one({"email": email})
        return jsonify({"success": False, "message": "Code has expired"}), 400

    return jsonify({"success": True, "message": "Code verified"}), 200

@app.route('/reset-password', methods=['POST'])
def reset_password():
    data = request.get_json()
    email = data.get('email')
    new_password = data.get('password')
    if not email or not new_password:
        return jsonify({"success": False, "message": "Email and new password are required"}), 400

    # Verify valid reset code
    reset_code = reset_codes_collection.find_one({"email": email})
    if not reset_code:
        return jsonify({"success": False, "message": "No valid reset code found"}), 404

    if datetime.utcnow() > reset_code['expires_at']:
        reset_codes_collection.delete_one({"email": email})
        return jsonify({"success": False, "message": "Reset code has expired"}), 400

    # Update password
    hashed_password = generate_password_hash(new_password)
    result = users_collection.update_one(
        {"email": email},
        {"$set": {"password": hashed_password}}
    )
    if result.modified_count > 0:
        reset_codes_collection.delete_one({"email": email})  # Clean up reset code
        return jsonify({"success": True, "message": "Password reset successfully"}), 200
    return jsonify({"success": False, "message": "Failed to reset password"}), 400
#_________________________________________________________

@app.route('/extract', methods=['POST'])
@jwt_required()
def extract_entities():
    print('Request files:', request.files)
    if 'image' not in request.files:
        return jsonify({"error": "No image uploaded"}), 400
    file = request.files['image']
    image = Image.open(file)

    # Extract text
    extracted_text = extract_text_from_image(image)
    clean_text = " ".join(extracted_text)
    result = process_entities(clean_text, model)

    # Extract QR code
    qr_url = extract_qr_code(image)

    # Store card data with user association
    current_user = get_jwt_identity()
    card_data = {
        "user": current_user,
        "person_name": result["Person Name"],
        "company_name": result["Company Name"],
        "job_title": result["Job Title"],
        "phone": result["Phone"],
        "email": result["Email"],
        "address": result["Address"],
        "qr_url": qr_url if qr_url else "",  # Store QR URL if found
        "timestamp": pd.Timestamp.now().isoformat()
    }
    cards_collection.insert_one(card_data)

    # Return result including QR URL if present
    if qr_url:
        result["QR URL"] = qr_url
    return jsonify(result)

@app.route('/cards', methods=['GET'])
@jwt_required()
def get_cards():
    current_user = get_jwt_identity()
    cards = cards_collection.find({'user': current_user}).sort('timestamp', -1)
    return jsonify([{
        'person_name': card.get('person_name', 'Unknown'),
        'company_name': card.get('company_name', ''),
        'job_title': card.get('job_title', ''),
        'phone': card.get('phone', ''),
        'email': card.get('email', ''),
        'address': card.get('address', ''),
        'qr_url': card.get('qr_url', ''),
        'timestamp': card.get('timestamp')
    } for card in cards])

@app.route('/cards', methods=['DELETE'])
@jwt_required()
def delete_card():
    current_user = get_jwt_identity()
    timestamp = request.args.get('timestamp')
    if not timestamp:
        return jsonify({"error": "Timestamp required"}), 400
    try:
        datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
    except ValueError:
        return jsonify({"error": "Invalid timestamp format"}), 400
    result = cards_collection.delete_one({'user': current_user, 'timestamp': timestamp})
    if result.deleted_count > 0:
        return jsonify({"message": "Card deleted"}), 200
    return jsonify({"error": "Card not found"}), 404



#  endpoint to get current user data
@app.route('/current_user', methods=['GET'])
@jwt_required()
def get_current_user():
    current_user = get_jwt_identity()
    user = users_collection.find_one({"username": current_user})
    if user:
        return jsonify({
            "username": user["username"],
            "email": user["email"]
        }), 200
    return jsonify({"error": "User not found"}), 404

#  endpoint to delete account
@app.route('/delete_account', methods=['DELETE'])
@jwt_required()
def delete_account():
    current_user = get_jwt_identity()
    result = users_collection.delete_one({"username": current_user})
    if result.deleted_count > 0:
        cards_collection.delete_many({"user": current_user})
        return jsonify({"message": "Account deleted successfully"}), 200
    return jsonify({"error": "Account deletion failed"}), 400


if __name__ == '__main__':
    from datetime import datetime
    app.run(host='0.0.0.0', port=5000, debug=True)