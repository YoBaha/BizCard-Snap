import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:bizcard_snap/services/api_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pw show PdfColor;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class CardVaultPage extends StatefulWidget {
  const CardVaultPage({super.key});

  @override
  _CardVaultPageState createState() => _CardVaultPageState();
}

class _CardVaultPageState extends State<CardVaultPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _cards = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'timestamp';
  bool _isAscending = false;
  final TextEditingController _searchController = TextEditingController();

  Future<void> _fetchCards() async {
    if (_apiService.token == null) {
      setState(() {
        _isLoading = false;
        _cards = [{'error': 'Please log in again'}];
      });
      return;
    }

    try {
      final response = await _apiService.getCards();
      if (response != null) {
        setState(() {
          _cards = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _cards = [{'error': 'Failed to load cards'}];
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _cards = [{'error': 'Error fetching cards: $e'}];
      });
    }
  }

  //PDF
  Future<void> _generatePdf(Map<String, dynamic> card) async {
    setState(() => _isLoading = true);
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Business Card Details',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Name: ${card['person_name'] ?? 'Unknown'}',
                  style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Company: ${card['company_name'] ?? ''}',
                  style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Job Title: ${card['job_title'] ?? ''}',
                  style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Phone: ${card['phone'] ?? ''}',
                  style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Email: ${card['email'] ?? ''}',
                  style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Address: ${card['address'] ?? ''}',
                  style: const pw.TextStyle(fontSize: 16)),
              if (card['qr_url']?.isNotEmpty == true)
                pw.Text('QR URL: ${card['qr_url']}',
                    style: const pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 20),
              pw.Text('Generated on: ${DateTime.now().toIso8601String()}',
                  style: const pw.TextStyle(fontSize: 12, color: pw.PdfColor(0.5, 0.5, 0.5))),
            ],
          ),
        ),
      );

      // Save PDF to temp
      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/business_card_${card['person_name']?.replaceAll(' ', '_') ?? 'card'}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved to ${file.path}')),
      );

      // Optionally share PDF
      await Share.shareXFiles([XFile(file.path)],
          text: 'Business Card: ${card['person_name'] ?? 'Unknown'}');
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredAndSortedCards {
    List<Map<String, dynamic>> filteredCards = _cards
        .where((card) =>
            card['person_name'] != null &&
            card['person_name']
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
        .toList();

    filteredCards.sort((a, b) {
      var aValue = a[_sortBy] ?? '';
      var bValue = b[_sortBy] ?? '';
      if (_sortBy == 'timestamp') {
        aValue = aValue.isNotEmpty ? DateTime.parse(aValue) : DateTime(0);
        bValue = bValue.isNotEmpty ? DateTime.parse(bValue) : DateTime(0);
      }
      int comparison = aValue.toString().compareTo(bValue.toString());
      return _isAscending ? comparison : -comparison;
    });

    return filteredCards;
  }

  @override
  void initState() {
    super.initState();
    _fetchCards();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCardDetails(Map<String, dynamic> card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () => _generatePdf(card),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Download as PDF'),
                    ),
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
              overflow: TextOverflow.ellipsis,
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by name...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white70),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _sortBy,
                    icon: Icon(
                      _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                      color: Colors.white70,
                    ),
                    dropdownColor: Colors.black.withOpacity(0.8),
                    items: [
                      DropdownMenuItem(
                        value: 'person_name',
                        child: Text(
                          'Name',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'company_name',
                        child: Text(
                          'Company',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'timestamp',
                        child: Text(
                          'Date',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          if (_sortBy == value) {
                            _isAscending = !_isAscending;
                          } else {
                            _sortBy = value;
                            _isAscending = true;
                          }
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Colors.white)),
              if (!_isLoading && _filteredAndSortedCards.isEmpty)
                const Center(
                  child: Text(
                    'No cards found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              if (!_isLoading && _filteredAndSortedCards.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredAndSortedCards.length,
                    itemBuilder: (context, index) {
                      final card = _filteredAndSortedCards[index];
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
                            onPressed: () => _deleteCard(
                                _cards.indexOf(card), card['timestamp']),
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