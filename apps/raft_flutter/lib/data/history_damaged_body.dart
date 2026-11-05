/// A saved chat row whose text is missing was blanked by an older client
/// (its cache codec nulled any string that merely mentioned a signed query).
/// It is not a complete body: durable reads must not present it as one, so the
/// normal revalidation fetch gets the server's row instead.
///
/// System rows and deleted rows carry no required text and are never damaged.
bool historyBodyDamaged(Map<dynamic, dynamic> row) =>
    row['content'] == null &&
    row['messageType'] != 'system' &&
    row['deleted'] != true &&
    row['deletedAt'] == null;

bool historyAnyBodyDamaged(Iterable<dynamic>? rows) =>
    rows != null && rows.any((row) => row is Map && historyBodyDamaged(row));
