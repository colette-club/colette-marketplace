import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:app/models/user.dart";
import "package:app/repos/user_repo.dart";

class MockUserRepo extends Mock implements UserRepo {}

void main() {
  group("user", () {
    test("returns the viewer", () async {
      final repo = MockUserRepo();
      const user = User(id: "1", name: "Ada");
      when(() => repo.user()).thenAnswer((_) async => user);

      expect(await repo.user(), user);
    });
  });
}
