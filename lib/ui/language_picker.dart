import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/tr.dart';
import '../profiles/profile.dart';
import '../theme/tv_theme.dart';
import 'widgets/tv_focus.dart';

/// The Language picker (app-languages): Automatic, then each language by its
/// own name. A choice applies at once and the picker stays open on it, so
/// the new language shows here too; Back closes it.
Future<void> showLanguagePicker(BuildContext context, Profile profile) => showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _LanguagePicker(profile: profile),
    );

class _LanguagePicker extends StatefulWidget {
  const _LanguagePicker({required this.profile});

  final Profile profile;

  @override
  State<_LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<_LanguagePicker> {
  late String? _choice = widget.profile.language;

  Future<void> _choose(String? language) async {
    setState(() => _choice = language);
    await HouseholdScope.read(context).setLanguage(widget.profile, language);
  }

  Widget _row(GuideTheme g, String label, String? language) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TvToggle(
            label: label,
            radio: true,
            on: _choice == language,
            autofocus: _choice == language,
            onPressed: () => _choose(language),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Dialog(
      backgroundColor: g.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(g.radius * 2),
        side: BorderSide(color: g.cellBorder, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(dialogPadding(context)),
        child: SizedBox(
          width: dialogWidth(context, 720, padding: dialogPadding(context)),
          child: dialogBody(
            context,
            FocusTraversalGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr.languageTitle, style: g.display(48, weight: FontWeight.w800)),
                  const SizedBox(height: 24),
                  _row(g, tr.languageAutomatic, null),
                  for (final language in supportedLanguages) _row(g, languageNativeNames[language]!, language),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
