import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

/// Ported from native `ComplainActivity.java`.
///
/// Allows users to submit a complaint with an optional screenshot.
class CreateComplaintScreen extends StatefulWidget {
  const CreateComplaintScreen({super.key});

  @override
  State<CreateComplaintScreen> createState() => _CreateComplaintScreenState();
}

class _CreateComplaintScreenState extends State<CreateComplaintScreen> {
  static const String _tag = 'Complaint';
  final _issueCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  File? _proofImage;
  bool _submitting = false;

  @override
  void dispose() {
    _issueCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: ImageSource.gallery);
      if (xFile != null) {
        setState(() => _proofImage = File(xFile.path));
      }
    } catch (e, s) {
      Log.e(_tag, 'pickImage failed', e, s);
    }
  }

  Future<void> _submit() async {
    final issue = _issueCtrl.text.trim();
    if (issue.isEmpty) {
      Fluttertoast.showToast(msg: 'Please describe your issue');
      return;
    }
    setState(() => _submitting = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.createComplaint(
        userId: session.userId,
        contactDetails: _contactCtrl.text.trim(),
        issue: issue,
        proofImage: _proofImage,
      );
      if (res.status) {
        Fluttertoast.showToast(msg: 'Complaint submitted');
        if (mounted) Navigator.pop(context);
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to submit');
      }
    } catch (e, s) {
      Log.e(_tag, 'submit failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to submit');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Complaint')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Issue *', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _issueCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Describe your issue...',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Contact Details', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _contactCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Email or phone (optional)',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Proof Screenshot', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _proofImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_proofImage!, fit: BoxFit.cover),
                      )
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Tap to add screenshot', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: Preloader(strokeWidth: 2))
                    : const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
