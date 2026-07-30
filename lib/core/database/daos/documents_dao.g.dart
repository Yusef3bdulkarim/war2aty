// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'documents_dao.dart';

// ignore_for_file: type=lint
mixin _$DocumentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DocumentsTable get documents => attachedDatabase.documents;
  $DocumentKeyInformationTable get documentKeyInformation =>
      attachedDatabase.documentKeyInformation;
  $DocumentDatesTable get documentDates => attachedDatabase.documentDates;
  $DocumentAmountsTable get documentAmounts => attachedDatabase.documentAmounts;
  $DocumentActionsTable get documentActions => attachedDatabase.documentActions;
  $DocumentWarningsTable get documentWarnings =>
      attachedDatabase.documentWarnings;
  $DocumentTextItemsTable get documentTextItems =>
      attachedDatabase.documentTextItems;
  DocumentsDaoManager get managers => DocumentsDaoManager(this);
}

class DocumentsDaoManager {
  final _$DocumentsDaoMixin _db;
  DocumentsDaoManager(this._db);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db.attachedDatabase, _db.documents);
  $$DocumentKeyInformationTableTableManager get documentKeyInformation =>
      $$DocumentKeyInformationTableTableManager(
        _db.attachedDatabase,
        _db.documentKeyInformation,
      );
  $$DocumentDatesTableTableManager get documentDates =>
      $$DocumentDatesTableTableManager(_db.attachedDatabase, _db.documentDates);
  $$DocumentAmountsTableTableManager get documentAmounts =>
      $$DocumentAmountsTableTableManager(
        _db.attachedDatabase,
        _db.documentAmounts,
      );
  $$DocumentActionsTableTableManager get documentActions =>
      $$DocumentActionsTableTableManager(
        _db.attachedDatabase,
        _db.documentActions,
      );
  $$DocumentWarningsTableTableManager get documentWarnings =>
      $$DocumentWarningsTableTableManager(
        _db.attachedDatabase,
        _db.documentWarnings,
      );
  $$DocumentTextItemsTableTableManager get documentTextItems =>
      $$DocumentTextItemsTableTableManager(
        _db.attachedDatabase,
        _db.documentTextItems,
      );
}
