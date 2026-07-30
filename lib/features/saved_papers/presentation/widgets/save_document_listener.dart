import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../cubit/save_document_cubit.dart';
import '../cubit/save_document_state.dart';

/// How long the save feedback stays up.
const Duration _feedback = Duration(seconds: 3);

/// Reports the outcome of a save over [child].
///
/// A listener rather than a builder: saving changes nothing on the page it is
/// invoked from — the paper is already on screen — so the only thing to show
/// is whether it worked. The confirmation names what was kept («النتيجة فقط»)
/// so the user is never left guessing whether the picture went with it
/// (privacy §7).
class SaveDocumentListener extends StatelessWidget {
  const SaveDocumentListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<SaveDocumentCubit, SaveDocumentState>(
      listenWhen: (previous, current) =>
          current is SaveDocumentSaved || current is SaveDocumentFailed,
      listener: (context, state) {
        final strings = context.strings;
        final message = switch (state) {
          SaveDocumentSaved() => strings.documentSaved,
          // The failure is not spelled out: the user cannot act on a database
          // error, and its text is English server/driver copy either way.
          _ => strings.documentSaveFailed,
        };

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message), duration: _feedback));
      },
      child: child,
    );
  }
}
