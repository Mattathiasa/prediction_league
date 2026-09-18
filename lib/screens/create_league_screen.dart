import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/league_provider.dart';
import '../services/auth_service.dart';
import '../services/league_service.dart';

class CreateLeagueScreen extends StatefulWidget {
  const CreateLeagueScreen({super.key});

  @override
  State<CreateLeagueScreen> createState() => _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends State<CreateLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late String _previewCode;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _previewCode = LeagueService().generateInviteCode();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _creating = true);

    final user = context.read<AuthService>().userModel!;
    final result = await context.read<LeagueProvider>().createLeague(
          name: _nameController.text.trim(),
          adminId: user.uid,
          inviteCode: _previewCode,
        );

    if (!mounted) return;
    setState(() => _creating = false);

    if (result != null) {
      Navigator.pop(context, result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('League created! Code: ${result.inviteCode}'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } else {
      final err = context.read<LeagueProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Failed to create league'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Create League',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('League Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDeco(hint: 'e.g. The Office League'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter a league name';
                  }
                  if (v.trim().length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              _label('Your Invite Code'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      _previewCode,
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Share this with friends so they can join',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() =>
                      _previewCode = LeagueService().generateInviteCode()),
                  icon: const Icon(Icons.refresh,
                      size: 15, color: Colors.white38),
                  label: const Text('New code',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _creating ? null : _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _creating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Create League',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600));

  InputDecoration _inputDeco({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        counterStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4CAF50))),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade700)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade700)),
      );
}
