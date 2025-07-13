import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:bizcard_snap/services/api_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class CardVaultPage extends StatefulWidget {
  const CardVaultPage({super.key});

  @override
  _CardVaultPageState createState() => _CardVaultPageState();
}

class _CardVaultPageState extends State<CardVaultPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _cards = [];
  bool _isLoading = true;

  Future<void> _fetchCards() async {
    if (_apiService.token == null) {
      setState(() {
        _isLoading = false;
        _cards = [{'error': 'Please log in again'}];
      });
      return;
    }

    try {
      final token = _apiService.token!;
      final userId = JwtDecoder.decode(token)['sub'];
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/cards?user=$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _cards = data.map((card) => Map<String, dynamic>.from(card)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _cards = [{'error': 'Failed to load cards: ${response.body}'}];
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _cards = [{'error': 'Error fetching cards: $e'}];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCards();
  }

  void _showCardDetails(Map<String, dynamic> card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Allow modal to take more space
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6, //60% 
        minChildSize: 0.3, 
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6441A5), Color(0xFF2a0845)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  card['person_name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _buildDetailRow('Company', card['company_name'] ?? ''),
                _buildDetailRow('Job Title', card['job_title'] ?? ''),
                _buildDetailRow('Phone', card['phone'] ?? ''),
                _buildDetailRow('Email', card['email'] ?? ''),
                _buildDetailRow('Address', card['address'] ?? ''),
                if (card['qr_url']?.isNotEmpty == true)
                  _buildDetailRow('QR URL', card['qr_url'] ?? ''),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              softWrap: true,
              maxLines: 3,
              overflow: TextOverflow.ellipsis, // Truncate with ellipsis
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCard(int index, String? timestamp) async {
    if (timestamp == null || _apiService.token == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}/cards?timestamp=$timestamp'),
        headers: {'Authorization': 'Bearer ${_apiService.token}'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _cards.removeAt(index);
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card deleted successfully')),
        );
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete card: ${response.body}')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting card: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6441A5), Color(0xFF2a0845)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Card Vault',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'View your saved business cards',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Colors.white)),
              if (!_isLoading && _cards.isEmpty)
                const Center(
                  child: Text(
                    'No cards saved yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              if (!_isLoading && _cards.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _cards.length,
                    itemBuilder: (context, index) {
                      final card = _cards[index];
                      if (card.containsKey('error')) {
                        return Center(
                          child: Text(
                            card['error']!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        color: Colors.white.withOpacity(0.1),
                        child: ListTile(
                          title: Text(
                            card['person_name'] ?? 'Unknown',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            card['company_name'] ?? '',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white),
                            onPressed: () => _deleteCard(index, card['timestamp']),
                          ),
                          onTap: () => _showCardDetails(card),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}