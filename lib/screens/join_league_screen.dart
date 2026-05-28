import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/league_provider.dart';
import '../services/auth_service.dart';

class JoinLeagueScreen extends StatefulWidget {
  const JoinLeagueScreen({super.key});

  @override
  State<JoinLeagueScreen> createState() => _JoinLeagueScreenState();
}

class _JoinLeagueScreenState extends State<JoinLeagueScreen> {
  final _codeController = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code must be exactly 6 characters')),
      );
      return;
    }

    setState(() => _joining = true);
    final user = context.read<AuthService>().userModel!;

    final result = await context.read<LeagueProvider>().joinLeagueByCode(
          code: code,
          userId: user.uid,
        );

    if (!mounted) return;
    setState(() => _joining = false);

    if (result != null) {
      Navigator.pop(context, result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined "${result.name}"!'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } else {
      final err = context.read<LeagueProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Failed to join league'),
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
        title: const Text('Join a League',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Invite Code',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              style: const TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(6),
                _UpperCaseFormatter(),
              ],
              decoration: InputDecoration(
                hintText: 'ABC123',
                hintStyle: const TextStyle(
                    color: Colors.white12,
                    fontSize: 30,
                    letterSpacing: 8),
                counterText: '',
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFF4CAF50))),
              ),
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ask the league creator to share their 6-character invite code.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _joining ? null : _join,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _joining
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Join League',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
