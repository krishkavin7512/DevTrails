import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../models/claim.dart';
import '../../services/api_service.dart';

class UploadEarningsProofScreen extends ConsumerStatefulWidget {
  final Claim claim;
  const UploadEarningsProofScreen({super.key, required this.claim});

  @override
  ConsumerState<UploadEarningsProofScreen> createState() =>
      _UploadEarningsProofScreenState();
}

class _UploadEarningsProofScreenState
    extends ConsumerState<UploadEarningsProofScreen> {
  final _formKey = GlobalKey<FormState>();
  final _earningsCtrl = TextEditingController();
  final _platformCtrl = TextEditingController();
  final _periodCtrl   = TextEditingController();
  final _notesCtrl    = TextEditingController();

  File? _proofImage;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _earningsCtrl.dispose();
    _platformCtrl.dispose();
    _periodCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (picked != null) {
      setState(() => _proofImage = File(picked.path));
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: RainCheckTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: RainCheckTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: RainCheckTheme.primary),
              title: const Text('Take a photo',
                  style: TextStyle(color: RainCheckTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: RainCheckTheme.primary),
              title: const Text('Choose from gallery',
                  style: TextStyle(color: RainCheckTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_proofImage == null) {
      setState(() => _error = 'Please attach a screenshot of your earnings.');
      return;
    }

    setState(() { _submitting = true; _error = null; });

    // Sends proof form fields; proofPath is local for now.
    // Backend /fraud/review/:claimId accepts action=submit_proof.
    final res = await ApiService().submitEarningsProof(widget.claim.id, {
      'earnings':  double.tryParse(_earningsCtrl.text) ?? 0,
      'platform':  _platformCtrl.text.trim(),
      'period':    _periodCtrl.text.trim(),
      'notes':     _notesCtrl.text.trim(),
    });

    setState(() => _submitting = false);

    if (!mounted) return;
    if (res.success) {
      Toast.success(context, 'Proof submitted — claim under review');
      Navigator.pop(context, true);
    } else {
      setState(() => _error = res.error ?? 'Submission failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      appBar: AppBar(
        title: const Text('Upload Earnings Proof'),
        backgroundColor: RainCheckTheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClaimBanner(claim: widget.claim),
              const SizedBox(height: 24),

              // Image picker
              const Text('Earnings Screenshot',
                  style: TextStyle(
                      color: RainCheckTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showImageSourceSheet,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: RainCheckTheme.surface,
                    border: Border.all(
                      color: _proofImage != null
                          ? RainCheckTheme.primary
                          : RainCheckTheme.surfaceVariant,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _proofImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(_proofImage!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload_file,
                                color: RainCheckTheme.primary, size: 40),
                            SizedBox(height: 8),
                            Text('Tap to attach screenshot',
                                style: TextStyle(
                                    color: RainCheckTheme.textSecondary,
                                    fontSize: 13)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Earnings amount
              _Field(
                controller: _earningsCtrl,
                label: 'Earnings during claim period (₹)',
                hint: 'e.g. 2500',
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Platform
              _Field(
                controller: _platformCtrl,
                label: 'Delivery platform',
                hint: 'e.g. Swiggy, Zomato, Blinkit',
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Period
              _Field(
                controller: _periodCtrl,
                label: 'Earnings period',
                hint: 'e.g. 01 Apr – 07 Apr 2026',
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Notes
              _Field(
                controller: _notesCtrl,
                label: 'Additional notes (optional)',
                hint: 'Any context that helps the review team',
                maxLines: 3,
              ),
              const SizedBox(height: 8),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: RainCheckTheme.error, fontSize: 13)),
                ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RainCheckTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Proof',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _ClaimBanner extends StatelessWidget {
  final Claim claim;
  const _ClaimBanner({required this.claim});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RainCheckTheme.warning.withAlpha(20),
        border: Border.all(color: RainCheckTheme.warning.withAlpha(80)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: RainCheckTheme.warning, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Claim ${claim.claimNumber} flagged for review',
                    style: const TextStyle(
                        color: RainCheckTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Fraud score: ${(claim.fraudScore * 100).toStringAsFixed(0)}% · ${claim.triggerType}',
                  style: const TextStyle(
                      color: RainCheckTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: RainCheckTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(color: RainCheckTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: RainCheckTheme.textSecondary),
            filled: true,
            fillColor: RainCheckTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: RainCheckTheme.surfaceVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: RainCheckTheme.surfaceVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: RainCheckTheme.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: RainCheckTheme.error),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
