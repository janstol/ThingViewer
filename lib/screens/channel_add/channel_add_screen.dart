import 'package:flutter/material.dart';

import '../../api/thingspeak_api.dart';
import '../../l10n/app_localizations.dart';
import '../../models/channel.dart';

const _defaultServerUrl = 'https://api.thingspeak.com';

class ChannelAddScreen extends StatefulWidget {
  final ThingSpeakApi api;
  final List<Channel> existingChannels;
  final Channel? initialChannel;

  const ChannelAddScreen({
    super.key,
    required this.api,
    this.existingChannels = const [],
    this.initialChannel,
  });

  @override
  State<ChannelAddScreen> createState() => _ChannelAddScreenState();
}

class _ChannelAddScreenState extends State<ChannelAddScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _serverUrlController;
  late final TextEditingController _channelIdController;
  late final TextEditingController _apiKeyController;

  late bool _isPublic;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialChannel;
    _serverUrlController = TextEditingController(
      text: initial?.serverUrl ?? _defaultServerUrl,
    );
    _channelIdController = TextEditingController(
      text: initial != null ? initial.id.toString() : '',
    );
    _apiKeyController = TextEditingController(text: initial?.apiKey ?? '');
    _isPublic = initial?.isPublic ?? true;
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _channelIdController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialChannel == null
              ? l10n.addChannelTitle
              : l10n.editChannelTitle,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _serverUrlController,
              decoration: InputDecoration(labelText: l10n.fieldServerUrl),
              keyboardType: TextInputType.url,
              validator: (v) => _validateServerUrl(v, l10n),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _channelIdController,
              decoration: InputDecoration(labelText: l10n.fieldChannelId),
              keyboardType: TextInputType.number,
              validator: (v) => _validateChannelId(v, l10n),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(l10n.fieldPublic)),
                ButtonSegment(value: false, label: Text(l10n.fieldPrivate)),
              ],
              selected: {_isPublic},
              onSelectionChanged: (s) => setState(() {
                _isPublic = s.first;
              }),
            ),
            if (!_isPublic) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _apiKeyController,
                decoration: InputDecoration(
                  labelText: l10n.fieldApiKey,
                  helperText: l10n.fieldApiKeyHelper,
                  helperMaxLines: 2,
                ),
                validator: (v) => _validateApiKey(v, l10n),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.labelSave),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateServerUrl(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) return l10n.errorServerUrl;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return l10n.errorServerUrlValid;
    }
    return null;
  }

  String? _validateChannelId(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) return l10n.errorChannelId;
    if (int.tryParse(value) == null) return l10n.errorChannelIdValid;
    return null;
  }

  String? _validateApiKey(String? value, AppLocalizations l10n) {
    if (!_isPublic && (value == null || value.isEmpty)) {
      return l10n.errorApiKey;
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final channel = Channel(
      id: int.parse(_channelIdController.text.trim()),
      serverUrl: _serverUrlController.text.trim(),
      isPublic: _isPublic,
      apiKey: _isPublic ? null : _apiKeyController.text.trim(),
    );

    try {
      final enriched = await widget.api.readChannel(channel);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final isDuplicate = widget.existingChannels.any(
        (c) => c == enriched && c != widget.initialChannel,
      );
      if (isDuplicate) {
        setState(() {
          _isSaving = false;
          _errorMessage = l10n.errorDuplicateChannel;
        });
        return;
      }
      Navigator.pop(context, enriched);
    } on ApiException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isSaving = false;
        _errorMessage = switch (e.code) {
          ApiErrorCode.network => l10n.errorNetwork,
          ApiErrorCode.credentials => l10n.errorApiCredentials,
          ApiErrorCode.general => e.serverMessage ?? l10n.errorGeneral,
        };
      });
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isSaving = false;
        _errorMessage = l10n.errorGeneral;
      });
    }
  }
}
