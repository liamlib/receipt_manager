import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const ReceiptManagerApp());
}

class ReceiptManagerApp extends StatelessWidget {
  const ReceiptManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0B7C72);

    return MaterialApp(
      title: 'Receipt Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF4F7F6),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const AuthFlow(),
    );
  }
}

enum AuthMode { login, createAccount }

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  AuthMode _mode = AuthMode.login;
  bool _isSignedIn = false;
  bool _allowEmailAccess = true;
  String? _accessToken;
  UserProfile? _profile;

  @override
  Widget build(BuildContext context) {
    if (_isSignedIn) {
      return AppShell(
        accessToken: _accessToken ?? '',
        initialProfile: _profile ?? UserProfile.empty(),
        onSignOut: _signOut,
      );
    }

    return AuthScreen(
      mode: _mode,
      allowEmailAccess: _allowEmailAccess,
      onLogin: () => setState(() => _mode = AuthMode.login),
      onCreateAccount: () => setState(() => _mode = AuthMode.createAccount),
      onEmailAccessChanged: (value) {
        setState(() => _allowEmailAccess = value ?? false);
      },
      onAuthenticated: (session) {
        setState(() {
          _accessToken = session.accessToken;
          _profile = session.profile;
          _isSignedIn = true;
        });
      },
    );
  }

  void _signOut() {
    setState(() {
      _isSignedIn = false;
      _accessToken = null;
      _profile = null;
      _mode = AuthMode.login;
    });
  }
}

class AuthScreen extends StatelessWidget {
  const AuthScreen({
    super.key,
    required this.mode,
    required this.allowEmailAccess,
    required this.onLogin,
    required this.onCreateAccount,
    required this.onEmailAccessChanged,
    required this.onAuthenticated,
  });

  final AuthMode mode;
  final bool allowEmailAccess;
  final VoidCallback onLogin;
  final VoidCallback onCreateAccount;
  final ValueChanged<bool?> onEmailAccessChanged;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.receipt_long, size: 58, color: colorScheme.primary),
                  const SizedBox(height: 18),
                  Text(
                    'Receipt Manager',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Receipts, returns, and spending in one calm place.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  SegmentedButton<AuthMode>(
                    segments: const [
                      ButtonSegment(
                        value: AuthMode.login,
                        icon: Icon(Icons.login),
                        label: Text('Login'),
                      ),
                      ButtonSegment(
                        value: AuthMode.createAccount,
                        icon: Icon(Icons.person_add_alt_1),
                        label: Text('Sign up'),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (selection) {
                      selection.first == AuthMode.login
                          ? onLogin()
                          : onCreateAccount();
                    },
                  ),
                  const SizedBox(height: 20),
                  AuthForm(
                    mode: mode,
                    allowEmailAccess: allowEmailAccess,
                    onEmailAccessChanged: onEmailAccessChanged,
                    onAuthenticated: onAuthenticated,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    required this.mode,
    required this.allowEmailAccess,
    required this.onEmailAccessChanged,
    required this.onAuthenticated,
  });

  final AuthMode mode;
  final bool allowEmailAccess;
  final ValueChanged<bool?> onEmailAccessChanged;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;
  String? _error;

  bool get _isCreating => widget.mode == AuthMode.createAccount;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = _isCreating ? 'Sign up' : 'Login';

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isCreating ? 'New account' : 'Welcome back',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          if (_isCreating) ...[
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _email,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
          ),
          if (_isCreating) ...[
            const SizedBox(height: 12),
            CheckboxListTile(
              value: widget.allowEmailAccess,
              onChanged: widget.onEmailAccessChanged,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Find receipts from email'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isLoading ? null : _submit,
            icon: _isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isCreating ? Icons.check : Icons.login),
            label: Text(_isLoading ? 'Please wait' : action),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = _isCreating
          ? await AuthApi.signUp(
              name: _name.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
            )
          : await AuthApi.login(
              email: _email.text.trim(),
              password: _password.text,
            );
      if (!mounted) return;
      widget.onAuthenticated(session);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class AuthApi {
  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );

  static Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/token/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _decode(response);
    final accessToken = data['access'] as String;
    return AuthSession(
      accessToken: accessToken,
      refreshToken: data['refresh']?.toString() ?? '',
      profile: await fetchProfile(accessToken),
    );
  }

  static Future<AuthSession> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final parts = name.split(RegExp(r'\s+'));
    final response = await http.post(
      Uri.parse('$_baseUrl/account/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'first_name': parts.isEmpty ? '' : parts.first,
        'last_name': parts.length < 2 ? '' : parts.sublist(1).join(' '),
      }),
    );
    final data = _decode(response);
    return AuthSession(
      accessToken: data['access'] as String,
      refreshToken: data['refresh']?.toString() ?? '',
      profile: UserProfile.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  static Future<UserProfile> fetchProfile(String accessToken) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/account/me/'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    return UserProfile.fromJson(_decode(response));
  }

  static Future<UserProfile> updateProfile({
    required String accessToken,
    required UserProfile profile,
  }) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/account/me/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(profile.toJson()),
    );
    return UserProfile.fromJson(_decode(response));
  }

  static Future<Uri> startGmailConnection(String accessToken) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/google/start/'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final data = _decode(response);
    return Uri.parse(data['authorization_url'] as String);
  }

  static Future<bool> fetchGmailStatus(String accessToken) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/google/status/'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final data = _decode(response);
    return data['connected'] == true;
  }

  static Future<bool> disconnectGmail(String accessToken) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/google/disconnect/'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final data = _decode(response);
    return data['connected'] == true;
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw Exception(_message(body));
  }

  static String _message(Map<String, dynamic> body) {
    if (body.containsKey('detail')) {
      final detail = body['detail'].toString();
      if (detail.toLowerCase().contains('no active account')) {
        return 'Wrong email or password.';
      }
      return detail;
    }
    if (body.isEmpty) return 'Could not connect to the backend.';
    return body.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n');
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.profile,
  });

  final String accessToken;
  final String refreshToken;
  final UserProfile profile;
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.currency,
    required this.profileImage,
    required this.gmailConnected,
  });

  final String name;
  final String email;
  final String phone;
  final String address;
  final String currency;
  final String profileImage;
  final bool gmailConnected;

  Uint8List? get avatarBytes {
    if (profileImage.isEmpty) return null;
    try {
      return base64Decode(profileImage);
    } catch (_) {
      return null;
    }
  }

  factory UserProfile.empty() {
    return const UserProfile(
      name: 'New account',
      email: '',
      phone: '',
      address: '',
      currency: 'USD',
      profileImage: '',
      gmailConnected: false,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final first = json['first_name']?.toString() ?? '';
    final last = json['last_name']?.toString() ?? '';
    final currencyValue = json['currency']?.toString() ?? '';
    final fullName = [first, last].where((part) => part.isNotEmpty).join(' ');
    return UserProfile(
      name: fullName.isEmpty ? 'New account' : fullName,
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      currency: currencyValue.isEmpty ? 'USD' : currencyValue,
      profileImage: json['profile_image']?.toString() ?? '',
      gmailConnected: json['gmail_connected'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    final parts = name.trim().split(RegExp(r'\s+'));
    return {
      'first_name': parts.isEmpty ? '' : parts.first,
      'last_name': parts.length < 2 ? '' : parts.sublist(1).join(' '),
      'phone': phone,
      'address': address,
      'currency': currency,
      'profile_image': profileImage,
    };
  }
}

enum AppPage { dashboard, receipts, stats, reminders, profile }

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.accessToken,
    required this.initialProfile,
    required this.onSignOut,
  });

  final String accessToken;
  final UserProfile initialProfile;
  final VoidCallback onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppPage _page = AppPage.dashboard;
  final List<Receipt> _receipts = List.of(seedReceipts);
  final List<Idea> _ideas = List.of(seedIdeas);
  Receipt? _selectedReceipt;
  DateTimeRange? _receiptRange;
  DateTimeRange? _statsRange;
  late String _name;
  late String _email;
  late String _phone;
  late String _address;
  late String _currency;
  late bool _gmailConnected;
  IconData _avatarIcon = Icons.person;
  Uint8List? _avatarBytes;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _name = profile.name;
    _email = profile.email;
    _phone = profile.phone;
    _address = profile.address;
    _currency = profile.currency;
    _gmailConnected = profile.gmailConnected;
    _avatarBytes = profile.avatarBytes;
  }

  List<Receipt> get _filteredReceipts {
    return _receipts.where((receipt) {
      final range = _page == AppPage.stats ? _statsRange : _receiptRange;
      if (range == null) return true;
      final start = DateUtils.dateOnly(range.start);
      final end = DateUtils.dateOnly(range.end);
      final date = DateUtils.dateOnly(receipt.purchasedAt);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Padding(
            key: ValueKey('${_page.name}-${_selectedReceipt?.id}'),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: _buildPage(),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(page: _page, onSelect: _openPage),
    );
  }

  Widget _buildPage() {
    if (_selectedReceipt != null) {
      return ReceiptDetailPage(
        receipt: _selectedReceipt!,
        onBack: () => setState(() => _selectedReceipt = null),
        onEdit: _editReceipt,
        onDelete: _confirmDeleteReceipt,
      );
    }

    switch (_page) {
      case AppPage.dashboard:
        return DashboardPage(
          receipts: _receipts,
          onRefresh: _refreshReceipts,
          onOpenReceipt: _openReceipt,
          onEditReceipt: _editReceipt,
          onDeleteReceipt: _confirmDeleteReceipt,
          onOpenReceipts: () => _openPage(AppPage.receipts),
          onOpenStats: () => _openPage(AppPage.stats),
        );
      case AppPage.receipts:
        return ReceiptsPage(
          receipts: _filteredReceipts,
          range: _receiptRange,
          onPickRange: () => _pickRange(isStats: false),
          onClearRange: () => setState(() => _receiptRange = null),
          onRefresh: _refreshReceipts,
          onOpenReceipt: _openReceipt,
          onEditReceipt: _editReceipt,
          onDeleteReceipt: _confirmDeleteReceipt,
        );
      case AppPage.stats:
        return StatsPage(
          receipts: _filteredReceipts,
          range: _statsRange,
          onPickRange: () => _pickRange(isStats: true),
          onClearRange: () => setState(() => _statsRange = null),
        );
      case AppPage.reminders:
        return RemindersPage(
          receipts: _receipts,
          onOpenReceipt: _openReceipt,
          onDeleteReceipt: _confirmDeleteReceipt,
        );
      case AppPage.profile:
        return ProfilePage(
          name: _name,
          email: _email,
          phone: _phone,
          address: _address,
          currency: _currency,
          avatarIcon: _avatarIcon,
          avatarBytes: _avatarBytes,
          gmailConnected: _gmailConnected,
          ideas: _ideas,
          onSave: _saveProfile,
          onPickAvatar: _pickAvatar,
          onConnectGmail: _connectGmail,
          onRefreshGmail: _refreshGmailStatus,
          onDisconnectGmail: _disconnectGmail,
          onAddIdea: _addIdea,
          onSignOut: widget.onSignOut,
        );
    }
  }

  void _openPage(AppPage page) {
    setState(() {
      _page = page;
      _selectedReceipt = null;
    });
  }

  void _openReceipt(Receipt receipt) {
    setState(() {
      _page = AppPage.receipts;
      _selectedReceipt = receipt;
    });
  }

  void _refreshReceipts() {
    if (_receipts.any((receipt) => receipt.id == 'backend-1')) {
      _showSnack('No missing receipts found');
      return;
    }
    setState(() => _receipts.insert(0, backendReceipt));
    _showSnack('1 missing receipt added');
  }

  Future<void> _confirmDeleteReceipt(Receipt receipt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete receipt?'),
        content: Text('Remove ${receipt.store} for ${receipt.amount}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _deleteReceipt(receipt);
  }

  void _deleteReceipt(Receipt receipt) {
    setState(() {
      _receipts.removeWhere((item) => item.id == receipt.id);
      if (_selectedReceipt?.id == receipt.id) _selectedReceipt = null;
    });
    _showSnack('Receipt deleted');
  }

  Future<void> _editReceipt(Receipt receipt) async {
    final edited = await showDialog<Receipt>(
      context: context,
      builder: (context) => EditReceiptDialog(receipt: receipt),
    );
    if (edited == null) return;
    setState(() {
      final index = _receipts.indexWhere((item) => item.id == receipt.id);
      if (index != -1) _receipts[index] = edited;
      if (_selectedReceipt?.id == receipt.id) _selectedReceipt = edited;
    });
    _showSnack('Receipt updated');
  }

  Future<void> _pickRange({required bool isStats}) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: isStats ? _statsRange : _receiptRange,
    );
    if (picked == null) return;
    setState(() {
      isStats ? _statsRange = picked : _receiptRange = picked;
    });
  }

  void _addIdea(String text) {
    setState(() {
      _ideas.insert(0, Idea(text: text, votes: 1));
    });
    _showSnack('Idea added');
  }

  Future<void> _pickAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() => _avatarBytes = bytes);
  }

  Future<void> _saveProfile(
    String name,
    String email,
    String phone,
    String address,
    String currency,
  ) async {
    try {
      final saved = await AuthApi.updateProfile(
        accessToken: widget.accessToken,
        profile: UserProfile(
          name: name.trim(),
          email: email.trim(),
          phone: phone.trim(),
          address: address.trim(),
          currency: currency.trim().isEmpty ? 'USD' : currency.trim(),
          profileImage: _avatarBytes == null ? '' : base64Encode(_avatarBytes!),
          gmailConnected: _gmailConnected,
        ),
      );
      setState(() {
        _name = saved.name;
        _email = saved.email;
        _phone = saved.phone;
        _address = saved.address;
        _currency = saved.currency;
        _avatarBytes = saved.avatarBytes;
        _gmailConnected = saved.gmailConnected;
      });
      _showSnack('Profile saved');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  Future<void> _connectGmail() async {
    try {
      final authorizationUrl = await AuthApi.startGmailConnection(widget.accessToken);
      final opened = await launchUrl(
        authorizationUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        _showSnack('Could not open Google sign-in.');
        return;
      }
      _showSnack('Finish Google sign-in, then refresh Gmail status.');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  Future<void> _refreshGmailStatus() async {
    try {
      final connected = await AuthApi.fetchGmailStatus(widget.accessToken);
      setState(() => _gmailConnected = connected);
      _showSnack(connected ? 'Gmail connected' : 'Gmail is not connected');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  Future<void> _disconnectGmail() async {
    try {
      final connected = await AuthApi.disconnectGmail(widget.accessToken);
      setState(() => _gmailConnected = connected);
      _showSnack('Gmail disconnected');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.page, required this.onSelect});

  final AppPage page;
  final ValueChanged<AppPage> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Panel(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              NavTab(page: AppPage.dashboard, current: page, onSelect: onSelect),
              NavTab(page: AppPage.receipts, current: page, onSelect: onSelect),
              NavTab(page: AppPage.stats, current: page, onSelect: onSelect),
              NavTab(page: AppPage.reminders, current: page, onSelect: onSelect),
              NavTab(page: AppPage.profile, current: page, onSelect: onSelect),
            ],
          ),
        ),
      ),
    );
  }
}

class NavTab extends StatelessWidget {
  const NavTab({
    super.key,
    required this.page,
    required this.current,
    required this.onSelect,
  });

  final AppPage page;
  final AppPage current;
  final ValueChanged<AppPage> onSelect;

  IconData get icon {
    switch (page) {
      case AppPage.dashboard:
        return Icons.home_rounded;
      case AppPage.receipts:
        return Icons.receipt_long_rounded;
      case AppPage.stats:
        return Icons.bar_chart_rounded;
      case AppPage.reminders:
        return Icons.notifications_rounded;
      case AppPage.profile:
        return Icons.person_rounded;
    }
  }

  String get label {
    switch (page) {
      case AppPage.dashboard:
        return 'Home';
      case AppPage.receipts:
        return 'Receipts';
      case AppPage.stats:
        return 'Stats';
      case AppPage.reminders:
        return 'Alerts';
      case AppPage.profile:
        return 'You';
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = page == current;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelect(page),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 58,
          decoration: BoxDecoration(
            color: selected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.receipts,
    required this.onRefresh,
    required this.onOpenReceipt,
    required this.onEditReceipt,
    required this.onDeleteReceipt,
    required this.onOpenReceipts,
    required this.onOpenStats,
  });

  final List<Receipt> receipts;
  final VoidCallback onRefresh;
  final ValueChanged<Receipt> onOpenReceipt;
  final ValueChanged<Receipt> onEditReceipt;
  final ValueChanged<Receipt> onDeleteReceipt;
  final VoidCallback onOpenReceipts;
  final VoidCallback onOpenStats;

  @override
  Widget build(BuildContext context) {
    final total = receipts.fold<double>(0, (sum, receipt) => sum + receipt.total);

    return PageFrame(
      title: 'Home',
      subtitle: 'Demo data. Email sync is not connected yet.',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      children: [
        const FriendlyBanner(),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            StatTile(
              icon: Icons.payments_rounded,
              label: 'Month',
              value: money(total),
              color: const Color(0xFFE2F7EF),
              onTap: onOpenStats,
            ),
            StatTile(
              icon: Icons.receipt_long_rounded,
              label: 'Found',
              value: '${receipts.length}',
              color: const Color(0xFFEAF0FF),
              onTap: onOpenReceipts,
            ),
            StatTile(
              icon: Icons.storefront_rounded,
              label: 'Top',
              value: topStore(receipts),
              color: const Color(0xFFFFF1D8),
              onTap: onOpenStats,
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionHeader(title: 'Receipts', action: onOpenReceipts),
        for (final receipt in receipts.take(3))
          ReceiptTile(
            receipt: receipt,
            onTap: () => onOpenReceipt(receipt),
            onEdit: () => onEditReceipt(receipt),
            onDelete: () => onDeleteReceipt(receipt),
          ),
      ],
    );
  }
}

class ReceiptsPage extends StatelessWidget {
  const ReceiptsPage({
    super.key,
    required this.receipts,
    required this.range,
    required this.onPickRange,
    required this.onClearRange,
    required this.onRefresh,
    required this.onOpenReceipt,
    required this.onEditReceipt,
    required this.onDeleteReceipt,
  });

  final List<Receipt> receipts;
  final DateTimeRange? range;
  final VoidCallback onPickRange;
  final VoidCallback onClearRange;
  final VoidCallback onRefresh;
  final ValueChanged<Receipt> onOpenReceipt;
  final ValueChanged<Receipt> onEditReceipt;
  final ValueChanged<Receipt> onDeleteReceipt;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Receipts',
      subtitle: rangeLabel(range),
      actions: [
        IconButton(
          tooltip: 'Date range',
          onPressed: onPickRange,
          icon: const Icon(Icons.date_range),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      children: [
        if (range != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onClearRange,
              icon: const Icon(Icons.close),
              label: const Text('Clear dates'),
            ),
          ),
        for (final receipt in receipts)
          ReceiptTile(
            receipt: receipt,
            onTap: () => onOpenReceipt(receipt),
            onEdit: () => onEditReceipt(receipt),
            onDelete: () => onDeleteReceipt(receipt),
          ),
      ],
    );
  }
}

class ReceiptDetailPage extends StatelessWidget {
  const ReceiptDetailPage({
    super.key,
    required this.receipt,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
  });

  final Receipt receipt;
  final VoidCallback onBack;
  final ValueChanged<Receipt> onEdit;
  final ValueChanged<Receipt> onDelete;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: receipt.store,
      subtitle: shortDate(receipt.purchasedAt),
      leading: IconButton(
        tooltip: 'Back',
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        IconButton(
          tooltip: 'Edit',
          onPressed: () => onEdit(receipt),
          icon: const Icon(Icons.edit),
        ),
        IconButton(
          tooltip: 'Delete',
          onPressed: () => onDelete(receipt),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
      children: [
        Panel(
          child: Column(
            children: [
              DetailRow(icon: Icons.payments, label: 'Total', value: receipt.amount),
              DetailRow(
                icon: Icons.assignment_return,
                label: 'Return',
                value: receipt.returnDate,
              ),
              DetailRow(icon: Icons.category, label: 'Type', value: receipt.category),
              const Divider(height: 28),
              for (final item in receipt.items)
                DetailRow(icon: Icons.sell_outlined, label: item, value: ''),
            ],
          ),
        ),
      ],
    );
  }
}

class StatsPage extends StatelessWidget {
  const StatsPage({
    super.key,
    required this.receipts,
    required this.range,
    required this.onPickRange,
    required this.onClearRange,
  });

  final List<Receipt> receipts;
  final DateTimeRange? range;
  final VoidCallback onPickRange;
  final VoidCallback onClearRange;

  @override
  Widget build(BuildContext context) {
    final total = receipts.fold<double>(0, (sum, receipt) => sum + receipt.total);
    final average = receipts.isEmpty ? 0.0 : total / receipts.length;
    final largest = receipts.isEmpty
        ? null
        : receipts.reduce((a, b) => a.total > b.total ? a : b);

    return PageFrame(
      title: 'Stats',
      subtitle: rangeLabel(range),
      actions: [
        IconButton(
          tooltip: 'Date range',
          onPressed: onPickRange,
          icon: const Icon(Icons.date_range),
        ),
      ],
      children: [
        if (range != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onClearRange,
              icon: const Icon(Icons.close),
              label: const Text('Clear dates'),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            StatTile(
              icon: Icons.payments,
              label: 'Spent',
              value: money(total),
              color: const Color(0xFFE2F7EF),
              onTap: onPickRange,
            ),
            StatTile(
              icon: Icons.receipt,
              label: 'Count',
              value: '${receipts.length}',
              color: const Color(0xFFEAF0FF),
              onTap: onPickRange,
            ),
            StatTile(
              icon: Icons.trending_up,
              label: 'Average',
              value: money(average),
              color: const Color(0xFFFFE7E1),
              onTap: onPickRange,
            ),
            StatTile(
              icon: Icons.store,
              label: 'Store',
              value: topStore(receipts),
              color: const Color(0xFFFFF1D8),
              onTap: onPickRange,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DetailRow(
                icon: Icons.shopping_bag,
                label: 'Largest',
                value: largest == null ? 'None' : largest.amount,
              ),
              DetailRow(
                icon: Icons.category,
                label: 'Top type',
                value: topCategory(receipts),
              ),
              DetailRow(
                icon: Icons.assignment_return,
                label: 'Returnable',
                value: '${receipts.where((r) => r.returnDate != 'None').length}',
              ),
              const Divider(height: 28),
              for (final entry in spendByStore(receipts).entries)
                StoreBar(
                  store: entry.key,
                  amount: money(entry.value),
                  fraction: total == 0 ? 0 : entry.value / total,
                ),
              const Divider(height: 28),
              for (final entry in spendByCategory(receipts).entries)
                StoreBar(
                  store: entry.key,
                  amount: money(entry.value),
                  fraction: total == 0 ? 0 : entry.value / total,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class RemindersPage extends StatelessWidget {
  const RemindersPage({
    super.key,
    required this.receipts,
    required this.onOpenReceipt,
    required this.onDeleteReceipt,
  });

  final List<Receipt> receipts;
  final ValueChanged<Receipt> onOpenReceipt;
  final ValueChanged<Receipt> onDeleteReceipt;

  @override
  Widget build(BuildContext context) {
    final reminders = receipts.where((receipt) => receipt.returnDate != 'None');

    return PageFrame(
      title: 'Alerts',
      subtitle: 'Return windows',
      children: [
        for (final receipt in reminders)
          CardTile(
            icon: Icons.notifications_active,
            color: const Color(0xFFFFE7E1),
            title: receipt.store,
            subtitle: receipt.returnDate,
            trailing: 'Open',
            onTap: () => onOpenReceipt(receipt),
            menu: PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz),
              onSelected: (value) {
                if (value == 'delete') onDeleteReceipt(receipt);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
      ],
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.currency,
    required this.avatarIcon,
    required this.avatarBytes,
    required this.gmailConnected,
    required this.ideas,
    required this.onSave,
    required this.onPickAvatar,
    required this.onConnectGmail,
    required this.onRefreshGmail,
    required this.onDisconnectGmail,
    required this.onAddIdea,
    required this.onSignOut,
  });

  final String name;
  final String email;
  final String phone;
  final String address;
  final String currency;
  final IconData avatarIcon;
  final Uint8List? avatarBytes;
  final bool gmailConnected;
  final List<Idea> ideas;
  final void Function(
    String name,
    String email,
    String phone,
    String address,
    String currency,
  ) onSave;
  final VoidCallback onPickAvatar;
  final VoidCallback onConnectGmail;
  final VoidCallback onRefreshGmail;
  final VoidCallback onDisconnectGmail;
  final ValueChanged<String> onAddIdea;
  final VoidCallback onSignOut;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _currency;
  final _idea = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _email = TextEditingController(text: widget.email);
    _phone = TextEditingController(text: widget.phone);
    _address = TextEditingController(text: widget.address);
    _currency = TextEditingController(text: widget.currency);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _currency.dispose();
    _idea.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'You',
      subtitle: 'Profile and account',
      children: [
        Panel(
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundImage: widget.avatarBytes == null
                    ? null
                    : MemoryImage(widget.avatarBytes!),
                child: widget.avatarBytes == null
                    ? Icon(widget.avatarIcon, size: 40)
                    : null,
              ),
              TextButton.icon(
                onPressed: widget.onPickAvatar,
                icon: const Icon(Icons.image),
                label: const Text('Pick image'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _currency,
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  widget.onSave(
                    _name.text,
                    _email.text,
                    _phone.text,
                    _address.text,
                    _currency.text,
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    widget.gmailConnected
                        ? Icons.mark_email_read_outlined
                        : Icons.mark_email_unread_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gmail',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: widget.gmailConnected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.gmailConnected ? 'Connected' : 'Not connected',
                      style: TextStyle(
                        color: widget.gmailConnected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.onConnectGmail,
                icon: const Icon(Icons.link),
                label: Text(widget.gmailConnected ? 'Reconnect Gmail' : 'Connect Gmail'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onRefreshGmail,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh status'),
              ),
              if (widget.gmailConnected) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: widget.onDisconnectGmail,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect Gmail'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ideas and feedback',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _idea,
                decoration: const InputDecoration(
                  labelText: 'Suggestion',
                  prefixIcon: Icon(Icons.lightbulb_outline),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () {
                  final text = _idea.text.trim();
                  if (text.isEmpty) return;
                  widget.onAddIdea(text);
                  _idea.clear();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add feedback'),
              ),
              const SizedBox(height: 12),
              for (final idea in widget.ideas)
                CardTile(
                  icon: Icons.tips_and_updates,
                  color: const Color(0xFFEAF0FF),
                  title: idea.text,
                  subtitle: '${idea.votes} votes',
                  trailing: 'Vote',
                  onTap: () => setState(() => idea.votes++),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class EditReceiptDialog extends StatefulWidget {
  const EditReceiptDialog({super.key, required this.receipt});

  final Receipt receipt;

  @override
  State<EditReceiptDialog> createState() => _EditReceiptDialogState();
}

class _EditReceiptDialogState extends State<EditReceiptDialog> {
  late final TextEditingController _store;
  late final TextEditingController _total;
  late final TextEditingController _category;
  late final TextEditingController _returnDate;

  @override
  void initState() {
    super.initState();
    _store = TextEditingController(text: widget.receipt.store);
    _total = TextEditingController(text: widget.receipt.total.toStringAsFixed(2));
    _category = TextEditingController(text: widget.receipt.category);
    _returnDate = TextEditingController(text: widget.receipt.returnDate);
  }

  @override
  void dispose() {
    _store.dispose();
    _total.dispose();
    _category.dispose();
    _returnDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit receipt'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _store, decoration: const InputDecoration(labelText: 'Store')),
            const SizedBox(height: 10),
            TextField(
              controller: _total,
              decoration: const InputDecoration(labelText: 'Total'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(controller: _category, decoration: const InputDecoration(labelText: 'Type')),
            const SizedBox(height: 10),
            TextField(
              controller: _returnDate,
              decoration: const InputDecoration(labelText: 'Return'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              widget.receipt.copyWith(
                store: _store.text.trim(),
                total: double.tryParse(_total.text) ?? widget.receipt.total,
                category: _category.text.trim(),
                returnDate: _returnDate.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      children: [
        Panel(
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: colorScheme.primary)),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E6E3)),
        boxShadow: const [
          BoxShadow(color: Color(0x10000000), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class FriendlyBanner extends StatelessWidget {
  const FriendlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFFFE7E1),
            child: Icon(Icons.waving_hand_rounded, color: Color(0xFFB84A2E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Found a missing receipt? Refresh checks the backend.',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(label, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.action});

  final String title;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(onPressed: action, child: const Text('All')),
      ],
    );
  }
}

class ReceiptTile extends StatelessWidget {
  const ReceiptTile({
    super.key,
    required this.receipt,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Receipt receipt;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CardTile(
      icon: Icons.receipt_long_rounded,
      color: const Color(0xFFEAF0FF),
      title: receipt.store,
      subtitle: '${shortDate(receipt.purchasedAt)}  ${receipt.category}',
      trailing: receipt.amount,
      onTap: onTap,
      menu: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz),
        onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.menu,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE0E6E3)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: color, child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: menu ??
            Text(trailing, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          if (value.isNotEmpty)
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class StoreBar extends StatelessWidget {
  const StoreBar({
    super.key,
    required this.store,
    required this.amount,
    required this.fraction,
  });

  final String store;
  final String amount;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(store)),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0).toDouble(),
            color: colorScheme.primary,
            backgroundColor: colorScheme.primaryContainer,
          ),
        ],
      ),
    );
  }
}

class Receipt {
  const Receipt({
    required this.id,
    required this.store,
    required this.total,
    required this.purchasedAt,
    required this.category,
    required this.returnDate,
    required this.items,
  });

  final String id;
  final String store;
  final double total;
  final DateTime purchasedAt;
  final String category;
  final String returnDate;
  final List<String> items;

  String get amount => money(total);

  Receipt copyWith({
    String? store,
    double? total,
    String? category,
    String? returnDate,
  }) {
    return Receipt(
      id: id,
      store: store ?? this.store,
      total: total ?? this.total,
      purchasedAt: purchasedAt,
      category: category ?? this.category,
      returnDate: returnDate ?? this.returnDate,
      items: items,
    );
  }
}

class Idea {
  Idea({required this.text, required this.votes});

  final String text;
  int votes;
}

String money(double value) => '\$${value.toStringAsFixed(2)}';

String shortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String rangeLabel(DateTimeRange? range) {
  if (range == null) return 'All dates';
  return '${shortDate(range.start)} - ${shortDate(range.end)}';
}

String topStore(List<Receipt> receipts) {
  if (receipts.isEmpty) return 'None';
  return spendByStore(receipts).entries.reduce((a, b) => a.value > b.value ? a : b).key;
}

String topCategory(List<Receipt> receipts) {
  if (receipts.isEmpty) return 'None';
  return spendByCategory(receipts).entries.reduce((a, b) => a.value > b.value ? a : b).key;
}

Map<String, double> spendByStore(List<Receipt> receipts) {
  final totals = <String, double>{};
  for (final receipt in receipts) {
    totals[receipt.store] = (totals[receipt.store] ?? 0) + receipt.total;
  }
  return totals;
}

Map<String, double> spendByCategory(List<Receipt> receipts) {
  final totals = <String, double>{};
  for (final receipt in receipts) {
    totals[receipt.category] = (totals[receipt.category] ?? 0) + receipt.total;
  }
  return totals;
}

final seedReceipts = [
  Receipt(
    id: '1',
    store: 'Target',
    total: 64.18,
    purchasedAt: DateTime(2026, 5, 8),
    category: 'Home',
    returnDate: 'May 31',
    items: const ['Storage bins', 'Laundry detergent', 'Notebook'],
  ),
  Receipt(
    id: '2',
    store: 'Amazon',
    total: 29.99,
    purchasedAt: DateTime(2026, 5, 7),
    category: 'Tech',
    returnDate: 'May 30',
    items: const ['USB-C cable', 'Screen cleaner'],
  ),
  Receipt(
    id: '3',
    store: 'Whole Foods',
    total: 88.47,
    purchasedAt: DateTime(2026, 4, 29),
    category: 'Food',
    returnDate: 'None',
    items: const ['Produce', 'Coffee', 'Lunch'],
  ),
  Receipt(
    id: '4',
    store: 'Best Buy',
    total: 219.99,
    purchasedAt: DateTime(2026, 4, 24),
    category: 'Tech',
    returnDate: 'May 8',
    items: const ['Wireless headphones'],
  ),
];

final backendReceipt = Receipt(
  id: 'backend-1',
  store: 'Zara',
  total: 48.90,
  purchasedAt: DateTime(2026, 5, 6),
  category: 'Clothes',
  returnDate: 'May 12',
  items: const ['Linen shirt'],
);

final seedIdeas = [
  Idea(text: 'Add warranty reminders', votes: 8),
  Idea(text: 'Export monthly spending as PDF', votes: 5),
];
