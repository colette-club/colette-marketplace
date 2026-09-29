import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:app/cubits/profile_cubit.dart";

class MockMainCubit extends Mock implements MainCubit {}
class MockUserRepo extends Mock implements UserRepo {}

void main() {
  group("save", () {
    test("returns true when the bio is saved", () async {
      final mainCubit = MockMainCubit();
      final repo = MockUserRepo();
      when(() => mainCubit.userRepo).thenReturn(repo);
      when(() => repo.updateBio("Hello")).thenAnswer((_) async {});
      final cubit = ProfileCubit(mainCubit: mainCubit);

      expect(await cubit.save("Hello"), isTrue);
      expect(cubit.state.loadingId, "");
    });
  });
}
