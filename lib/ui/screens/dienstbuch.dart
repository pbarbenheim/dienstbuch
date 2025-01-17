import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../repository/repository.dart';
import '../frame.dart';
import '../routes.dart';
import '../widgets/dienstbuch.dart';
import '../../pdf/pdf.dart';

class DienstbuchScreen extends ConsumerWidget {
  final int? id;
  const DienstbuchScreen({super.key, this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref
        .watch(repositoryProvider.select((value) => value!.getAllEintrage()))
        .entries
        .map(
          (e) => EintragItem(
            id: e.key,
            beginn: e.value.$1,
            thema: e.value.$2,
            getEintrag: () => ref.read(repositoryProvider)!.getEintrag(e.key),
          ),
        )
        .toList();
    EintragItem? selectedItem;
    try {
      selectedItem = items.firstWhere((element) => element.id == id);
    } catch (e) {
      // Nothing to catch
    }

    return ListDetail(
      items: items,
      onChanged: (value) {
        EintragRoute(value.id).go(context);
      },
      listHeader: "Dienstbuch-Einträge",
      destination: Destination.julog,
      selectedItem: selectedItem,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          const AddDienstbuchEintragRoute().go(context);
        },
        child: const Icon(Icons.add),
      ),
      itemActions: [
        //if (selectedItem != null)
        IconButton(
          onPressed: () {
            showAdaptiveDialog(
              context: context,
              builder: (context) => Dialog.fullscreen(
                child: PdfPreview(
                  allowPrinting: true,
                  allowSharing: true,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  initialPageFormat: PdfPageFormat.a4,
                  //Change that
                  canDebug: true,
                  build: (format) =>
                      selectedItem!.getEintrag().buildPdf(format),
                ),
              ),
            );
          },
          icon: const Icon(Icons.picture_as_pdf),
        ),
      ],
    );
  }
}

class AddDienstbuchEintragScreen extends StatelessWidget {
  const AddDienstbuchEintragScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return JulogScaffold(
      body: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 15),
          child: AddDienstbuchEintragForm(),
        ),
      ),
      destination: Destination.julog,
      appBar: AppBar(
        title: const Text("Eintrag hinzufügen"),
      ),
    );
  }
}

class SignEintragScreen extends ConsumerWidget {
  final int id;
  const SignEintragScreen({super.key, required this.id});

  Future<String?> _getPassword(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    final result = await showAdaptiveDialog<String?>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              const Text(
                "Gebe dein Passwort zum Signieren an.",
                softWrap: true,
              ),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  label: Text("Passwort"),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.visiblePassword,
                obscureText: true,
                onSubmitted: (value) {
                  Navigator.pop(context, value);
                },
              ),
              const Padding(padding: EdgeInsets.only(top: 6)),
              TextButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text("Weiter"))
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider)!;
    final eintrag = repo.getEintrag(id);
    final userIds = repo
        .getSigningUserIds()
        .where((element) =>
            !eintrag.signaturen.map((e) => e.userId).contains(element))
        .map((element) {
      final e = Repository.userIdToComponents(element);
      return ListTile(
        title: Text(e.$2 == "" ? "${e.$1}, ${e.$2}" : e.$1),
        onTap: () async {
          final password = await _getPassword(context);
          if (password == null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Du musst ein Password eingeben!")));
            }
            return;
          }

          /*try {*/
          await eintrag.sign(element, password);
          if (context.mounted) {
            EintragRoute(id).go(context);
          }
          /* } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Signieren nicht erfolgreich.")));
                }
                return;
              }*/
        },
      );
    }).toList();

    return JulogScaffold(
      destination: Destination.julog,
      appBar: AppBar(
        title: const Text("Eintrag unterschreiben"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ListView(
            children: userIds,
          ),
        ),
      ),
    );
  }
}
