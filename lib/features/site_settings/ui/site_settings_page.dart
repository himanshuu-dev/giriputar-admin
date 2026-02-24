import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/site_settings_providers.dart';
import '../../../core/providers/supabase_providers.dart';

class SiteSettingsPage extends ConsumerStatefulWidget {
  const SiteSettingsPage({super.key});

  @override
  ConsumerState<SiteSettingsPage> createState() => _SiteSettingsPageState();
}

class _SiteSettingsPageState extends ConsumerState<SiteSettingsPage> {
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final instagramController = TextEditingController();
  final facebookController = TextEditingController();
  final twitterController = TextEditingController();
  bool initialized = false;
  bool saving = false;

  @override
  void dispose() {
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    instagramController.dispose();
    facebookController.dispose();
    twitterController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => saving = true);
    final client = ref.read(supabaseClientProvider);
    try {
      await client.from('site_settings').upsert({
        'id': 1,
        'contact_email': emailController.text.trim(),
        'contact_phone': phoneController.text.trim(),
        'contact_address': addressController.text.trim(),
        'instagram_url': instagramController.text.trim(),
        'facebook_url': facebookController.text.trim(),
        'twitter_url': twitterController.text.trim(),
      });
      ref.invalidate(siteSettingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(siteSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Site Settings')),
      body: settingsAsync.when(
        data: (settings) {
          if (!initialized) {
            initialized = true;
            emailController.text = settings['contact_email']?.toString() ?? '';
            phoneController.text = settings['contact_phone']?.toString() ?? '';
            addressController.text =
                settings['contact_address']?.toString() ?? '';
            instagramController.text =
                settings['instagram_url']?.toString() ?? '';
            facebookController.text =
                settings['facebook_url']?.toString() ?? '';
            twitterController.text = settings['twitter_url']?.toString() ?? '';
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Contact Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Contact Phone'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Contact Address'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: instagramController,
                decoration: const InputDecoration(labelText: 'Instagram URL'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: facebookController,
                decoration: const InputDecoration(labelText: 'Facebook URL'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: twitterController,
                decoration: const InputDecoration(labelText: 'Twitter URL'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving...' : 'Save'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
