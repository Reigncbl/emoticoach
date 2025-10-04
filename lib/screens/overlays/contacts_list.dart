import 'package:flutter_svg/flutter_svg.dart';
import 'package:emoticoach/services/telegram_service.dart';
import 'package:emoticoach/utils/colors.dart';
import 'package:emoticoach/utils/auth_utils.dart';

class ContactsListView extends StatefulWidget {
  final Function(Map<String, dynamic>) onContactSelected;
  final VoidCallback onClose;
  final String? userMobileNumber;

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
  final TelegramService _telegramService = TelegramService();

  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;
  bool _isUsingTelegram = false;
  String? _errorMessage;
  int? _updatingContactId;

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

      // Get userId using safe method that prioritizes session data
      String? userId = await AuthUtils.getSafeUserId();

      if (userId == null || userId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not authenticated. Please log in again.';
        });
        return;
      }

      final statusResult = await _telegramService.getMe(userId: userId);

      print('Status result: $statusResult');

      if (statusResult['id'] != null) {
        print('User is authenticated, fetching contacts...');

        // Get Telegram contacts
        final contactsResult = await _telegramService.getContacts(
          userId: userId,
        );

        print('Contacts result: $contactsResult');

        if (contactsResult['contacts'] != null) {
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

  Future<void> _handleContactTap(Map<String, dynamic> contact) async {
    final rawContactId = contact['id'];
    final contactId = rawContactId is int
        ? rawContactId
        : int.tryParse(rawContactId?.toString() ?? '');

    if (contactId == null) {
      print('⚠️ Unable to parse contact id for ${contact['name']}');
      widget.onContactSelected(contact);
      return;
    }

    final userId = await AuthUtils.getSafeUserId();
    if (userId == null || userId.isEmpty) {
      print('⚠️ Unable to refresh latest message: missing user session');
      widget.onContactSelected(contact);
      return;
    }

    setState(() {
      _updatingContactId = contactId;
    });

    try {
      final result = await _telegramService.appendLatestContactMessage(
        userId: userId,
        contactId: contactId,
      );

      if (result['success'] != true) {
        print('⚠️ appendLatestContactMessage failed: ${result['error']}');
      } else {
        print('✅ Latest message appended for contact $contactId');
      }
    } catch (e) {
      print('❌ Error appending latest contact message: $e');
    } finally {
      if (mounted) {
        setState(() {
          _updatingContactId = null;
        });
      }
    }

    widget.onContactSelected(contact);
  }

  void _openTutorial() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent, // Remove the black overlay
      builder: (BuildContext context) {
        return _buildTutorialDialog();
      },
    );
  }

  Widget _buildTutorialDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              spreadRadius: 3,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title section
            Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/AI-Chat-nav.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    kPrimaryBlue,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Contacts Screen Guide',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Content section
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTutorialSection(
                    icon: Icons.telegram,
                    title: 'Telegram Integration',
                    description:
                        'Connect your Telegram account to access your contacts directly from the app.',
                  ),
                  const SizedBox(height: 16),
                  _buildTutorialSection(
                    icon: Icons.person_add,
                    title: 'Select Contacts',
                    description:
                        'Tap on any contact to start a conversation or view their chat history.',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Make sure you\'re logged into Telegram to see your contacts here.',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Actions section
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Got it!',
                  style: TextStyle(
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialSection({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kPrimaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: kPrimaryBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth;
    final maxWidth = 600.0;
    final finalWidth = containerWidth > maxWidth ? maxWidth : containerWidth;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Container(
        width: finalWidth,
        height: 450,
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
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.transparent,
                  child: SvgPicture.asset(
                    'assets/icons/AI-Chat-nav.svg',
                    width: 40,
                    height: 40,
                    colorFilter: const ColorFilter.mode(
                      kPrimaryBlue,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _openTutorial,
                  icon: const Icon(Icons.info, color: kPrimaryBlue, size: 22),
                  tooltip: 'Contact screen tutorial',
                ),
                if (!_isLoading && !_isUsingTelegram)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _retryLoadContacts,
                    icon: const Icon(
                      Icons.refresh,
                      color: kPrimaryBlue,
                      size: 24,
                    ),
                    tooltip: 'Try loading Telegram contacts',
                  ),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(2),
                    child: const Icon(
                      Icons.close,
                      color: kPrimaryBlue,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0057E4), Color(0xFF006EFF)],
              ),
            ),
            child: const Text(
              'Contacts',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.start,
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
      onTap: () => _handleContactTap(contact),
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
    final rawContactId = contact['id'];
    final contactId = rawContactId is int
        ? rawContactId
        : int.tryParse(rawContactId?.toString() ?? '');
    final isUpdating = contactId != null && contactId == _updatingContactId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isUpdating)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
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
        if (!isUpdating && contact['hasNewMessage'] == true)
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

  @override
  void dispose() {
    _telegramService.dispose();
    super.dispose();
  }
}
