import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await dotenv.load();
  }
  await Supabase.initialize(
    url: kIsWeb ? 'https://dktxspcehngtrbnvhkfh.supabase.co' : dotenv.env['SUPABASE_URL']!,
    anonKey: kIsWeb ? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRrdHhzcGNlaG5ndHJibnZoa2ZoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE1MTg5MTgsImV4cCI6MjA1NzA5NDkxOH0.jqN6T0KBFU0rzgxZFBp0ngE0s0Ug0jA4qUKs1uxD7tw' : dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heronfit Receipt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Heronfit Receipt'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _receiptController = TextEditingController();

  String? _errorText;
  bool _isLoading = false;

  Future<void> _issueReceipt() async {
    setState(() { _errorText = null; });
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });
      final email = _emailController.text;
      final receiptNumber = int.parse(_receiptController.text);

      try {
        // 1. Get user by email
        final userResponse = await Supabase.instance.client
            .from('users')
            .select('id')
            .eq('email_address', email)
            .maybeSingle();

        if (userResponse == null) {
          setState(() {
            _errorText = 'User not found';
          });
        } else {
          final userId = userResponse['id'];

          // 2. Check if user already has an available or pending ticket
          final activeOrPendingTicketResponse = await Supabase.instance.client
              .from('user_tickets')
              .select('id')
              .eq('user_email', email)
              .or('status.eq.available,status.eq.pending_booking')
              .maybeSingle();

          if (activeOrPendingTicketResponse != null) {
            setState(() {
              _errorText = 'User already has an available or pending ticket';
            });
            setState(() { _isLoading = false; });
            return;
          }

          // 3. Check if the ticket_code (receipt number) is unique
          final existingTicketResponse = await Supabase.instance.client
              .from('user_tickets')
              .select('id')
              .eq('ticket_code', receiptNumber.toString())
              .maybeSingle();

          if (existingTicketResponse != null) {
            setState(() {
              _errorText = 'This receipt number is already in use';
            });
            setState(() { _isLoading = false; });
            return;
          }

          // 4. Insert new ticket into user_tickets (remove created_at, ensure user_id is string)
          final ticketResponse = await Supabase.instance.client
              .from('user_tickets')
              .insert({
                'user_id': userId.toString(),
                'user_email': email,
                'ticket_code': receiptNumber.toString(),
                'status': 'available',
              })
              .select();

          if (ticketResponse.isEmpty) {
            setState(() {
              _errorText = 'Failed to issue ticket';
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Receipt issued successfully!')),
            );
            _emailController.clear();
            _receiptController.clear();
          }
        }
      } catch (e) {
        setState(() {
          _errorText = 'An error occurred: '
              + e.toString();
        });
      } finally {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Update the UI for better aesthetics
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'HERONFIT - RECEIPT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          hintText: 'Enter your email',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an email';
                          }
                          final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                          if (!emailRegex.hasMatch(value)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Receipt ID', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _receiptController,
                        maxLength: 7,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          hintText: '7-digit receipt number',
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter receipt ID';
                          }
                          if (value.length != 7 || int.tryParse(value) == null) {
                            return 'Enter a valid 7-digit number';
                          }
                          return null;
                        },
                      ),
                      if (_errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _errorText!,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                          ),
                          onPressed: _isLoading ? null : _issueReceipt,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'ISSUE RECEIPT',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ),
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
