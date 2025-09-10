import 'package:flutter/material.dart';
import '../../utils/api_service.dart';

class ContactsListView extends StatefulWidget {
  final Function(Map<String, dynamic>)
  onContactSelected; // Pass full contact data
  final VoidCallback onClose;
  final String? userMobileNumber; // For Telegram API calls

  const ContactsListView({
    super.key,
    required this.onContactSelected,
    required this.onClose,
    this.userMobileNumber,
  });

  @override
  State<ContactsListView> createState() => _ContactsListViewState();
}

class _ContactsListViewState extends State<ContactsListView> {
  final APIService _apiService = APIService();

  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;
  bool _isUsingTelegram = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Try to get Telegram contacts if user mobile number is available
      if (widget.userMobileNumber != null) {
        await _loadTelegramContacts();
      } else {
        // No user mobile number, show empty state
        setState(() {
          _contacts = [];
          _isUsingTelegram = false;
          _isLoading = false;
          _errorMessage = 'No user mobile number provided';
        });
      }
    } catch (e) {
      print('Error loading contacts: $e');
      setState(() {
        _contacts = [];
        _isUsingTelegram = false;
        _isLoading = false;
        _errorMessage = 'Failed to load contacts: ${e.toString()}';
      });
    }
  }

  Future<void> _loadTelegramContacts() async {
    try {
      // First check if user is authenticated with Telegram
      print('Checking Telegram authentication status...');
      final statusResult = await _apiService.getTelegramStatus(
        widget.userMobileNumber!,
      );

      print('Status result: $statusResult');

      if (statusResult['success'] == true &&
          statusResult['authenticated'] == true) {
        print('User is authenticated, fetching contacts...');

        // Get Telegram contacts
        final contactsResult = await _apiService.getTelegramContacts(
          widget.userMobileNumber!,
        );

        print('Contacts result: $contactsResult');

        if (contactsResult['success'] == true &&
            contactsResult['contacts'] != null) {
          final telegramContacts = contactsResult['contacts'] as List;

          setState(() {
            _contacts = telegramContacts.map((contact) {
              return {
                'id': contact['id'],
                'name':
                    contact['name'] ??
                    contact['first_name'] ??
                    'Unknown Contact',
                'username': contact['username'],
                'phone': contact['phone'],
                'avatar': Icons.person,
                'lastMessage': 'Tap to view messages',
                'time': 'Online',
                'hasNewMessage': false,
                'source': 'telegram',
              };
            }).toList();
            _isUsingTelegram = true;
            _isLoading = false;
          });

          print('Loaded ${_contacts.length} Telegram contacts');
        } else {
          // No contacts or error
          setState(() {
            _contacts = [];
            _isUsingTelegram = false;
            _isLoading = false;
            _errorMessage = contactsResult['error'] ?? 'No contacts found';
          });
        }
      } else {
        // User not authenticated
        setState(() {
          _contacts = [];
          _isUsingTelegram = false;
          _isLoading = false;
          _errorMessage =
              statusResult['error'] ?? 'Not authenticated with Telegram';
        });
      }
    } catch (e) {
      print('Error loading Telegram contacts: $e');
      setState(() {
        _contacts = [];
        _isUsingTelegram = false;
        _isLoading = false;
        _errorMessage = 'Failed to load Telegram contacts: ${e.toString()}';
      });
    }
  }

  Future<void> _retryLoadContacts() async {
    await _loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth * 0.95;
    final maxWidth = 500.0;
    final finalWidth = containerWidth > maxWidth ? maxWidth : containerWidth;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        width: finalWidth,
        height: 550,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            _isLoading ? _buildLoadingState() : _buildContactsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isUsingTelegram ? Colors.blue : Colors.blue,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Icon(
              _isUsingTelegram ? Icons.telegram : Icons.contacts,
              color: Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Contact',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _isUsingTelegram
                      ? 'From Telegram (${_contacts.length})'
                      : _contacts.isEmpty
                      ? 'No contacts retrieved'
                      : 'Local contacts',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          if (!_isLoading && !_isUsingTelegram)
            IconButton(
              onPressed: _retryLoadContacts,
              icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
              tooltip: 'Try loading Telegram contacts',
            ),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading contacts...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList() {
    if (_contacts.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'No contacts retrieved',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Connect Telegram to see your contacts',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          final contact = _contacts[index];
          return _buildContactItem(contact);
        },
      ),
    );
  }

  Widget _buildContactItem(Map<String, dynamic> contact) {
    return GestureDetector(
      onTap: () => widget.onContactSelected(contact),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: contact['hasNewMessage'] == true
                ? Colors.blue.shade200
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            _buildContactAvatar(contact),
            const SizedBox(width: 12),
            _buildContactInfo(contact),
            _buildContactMeta(contact),
          ],
        ),
      ),
    );
  }

  Widget _buildContactAvatar(Map<String, dynamic> contact) {
    final isFromTelegram = contact['source'] == 'telegram';

    return Stack(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.blue.shade100,
          child: Icon(
            contact['avatar'] ?? Icons.person,
            color: Colors.blue,
            size: 20,
          ),
        ),
        if (contact['hasNewMessage'] == true)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        if (isFromTelegram)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Icon(Icons.telegram, color: Colors.white, size: 8),
            ),
          ),
      ],
    );
  }

  Widget _buildContactInfo(Map<String, dynamic> contact) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contact['name'] ?? 'Unknown Contact',
            style: TextStyle(
              fontWeight: contact['hasNewMessage'] == true
                  ? FontWeight.bold
                  : FontWeight.w500,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          if (contact['username'] != null) ...[
            Text(
              '@${contact['username']}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            contact['lastMessage'] ?? 'No recent messages',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: contact['hasNewMessage'] == true
                  ? FontWeight.w500
                  : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildContactMeta(Map<String, dynamic> contact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          contact['time'] ?? '',
          style: TextStyle(
            fontSize: 11,
            color: contact['hasNewMessage'] == true
                ? Colors.blue
                : Colors.grey.shade500,
            fontWeight: contact['hasNewMessage'] == true
                ? FontWeight.w500
                : FontWeight.normal,
          ),
        ),
        if (contact['hasNewMessage'] == true)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'New',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
