import "package:bloc/bloc.dart";
import "package:equatable/equatable.dart";
import "package:app/cubits/main_cubit.dart";

part "profile_state.dart";

class ProfileCubit extends Cubit<ProfileState> {
  final MainCubit mainCubit;

  ProfileCubit({required this.mainCubit}) : super(const ProfileState());

  Future<bool> save(String bio) async {
    emit(state.copyWith(loadingId: "save"));
    try {
      await mainCubit.userRepo.updateBio(bio);
      emit(state.copyWith(loadingId: ""));
      return true;
    } catch (error, stacktrace) {
      emit(state.copyWith(loadingId: ""));
      // ignore: invalid_use_of_protected_member
      Bloc.observer.onError(this, error, stacktrace);
      return false;
    }
  }
}
