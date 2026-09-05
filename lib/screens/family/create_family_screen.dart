/// Create family screen — lets users create a new family.
///
/// Calls `/family/create` with name, description, image, visibility,
/// join code, and welcome message.
library create_family;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class CreateFamilyScreen extends StatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  State<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<CreateFamilyScreen> {
  static const String _tag = 'CreateFamily';

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _welcomeCtrl = TextEditingController();
  final _joinCodeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _imagePath;
  bool _isPublic = true;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _welcomeCtrl.dispose();
    _joinCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: ImageSource.gallery);
      if (xFile != null) {
        setState(() => _imagePath = xFile.path);
      }
    } catch (e, s) {
      Log.e(_tag, 'pickImage failed', e, s);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Fluttertoast.showToast(msg: 'Enter family name');
      return;
    }

    setState(() => _submitting = true);

    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.createFamily(
        userId: session.userId,
        name: name,
        description: _descCtrl.text.trim(),
        logoFile: _imagePath != null ? File(_imagePath!) : null,
        isPublic: _isPublic,
        joinCode: !_isPublic ? _joinCodeCtrl.text.trim() : '',
        welcomeMessage: _welcomeCtrl.text.trim(),
      );

      if (res.status) {
        Fluttertoast.showToast(msg: 'Family created successfully!');
        if (mounted) context.pop();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to create family');
      }
    } catch (e, s) {
      Log.e(_tag, 'createFamily failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to create family');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Family'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: _imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate,
                                size: 48, color: AppTheme.primary),
                            SizedBox(height: 8),
                            Text('Upload Family Image',
                                style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Family Name',
                  prefixIcon: Icon(Icons.group),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                  hintText: 'Tell people what your family is about...',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _welcomeCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Welcome Message (optional)',
                  prefixIcon: Icon(Icons.waving_hand),
                  hintText: 'Shown to new members when they join',
                ),
              ),
              const SizedBox(height: 16),
              // Visibility toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_isPublic ? Icons.lock_open : Icons.lock,
                            color: _isPublic ? AppTheme.green : AppTheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isPublic ? 'Public Family' : 'Private Family',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                _isPublic
                                    ? 'Anyone can join without a code'
                                    : 'Requires a join code to enter',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isPublic,
                          onChanged: (v) => setState(() => _isPublic = v),
                          thumbColor: WidgetStateProperty.resolveWith((states) =>
                              states.contains(WidgetState.selected) ? AppTheme.primary : null),
                        ),
                      ],
                    ),
                    if (!_isPublic) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _joinCodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Join Code',
                          prefixIcon: Icon(Icons.key),
                          hintText: 'Enter a secret code for joining',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: Preloader(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create Family', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

