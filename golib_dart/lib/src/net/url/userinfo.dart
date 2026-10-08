part of '../../../net/url.dart';

/// `url.Userinfo`: usuário e senha imutáveis.
final class Userinfo extends GoStruct<Userinfo>
    implements fmt.Stringer, Golang.GoTyped {
  Userinfo({
    Golang.String? username,
    Golang.String? password,
    bool? passwordSet,
  }) : _username = username ?? Golang.String(),
       _password = password ?? Golang.String(),
       _passwordSet = passwordSet ?? false;

  /// `(*Userinfo)(nil)` dentro de uma interface ou como receptor.
  static final Userinfo $nil = Userinfo()..$nilPtr = true;

  Golang.String _username;
  Golang.String _password;
  bool _passwordSet;

  @override
  String get $goType => 'url.Userinfo';
  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const ['Password', 'String', 'Username'];
  @override
  Userinfo $copy() => Userinfo(
    username: _username,
    password: _password,
    passwordSet: _passwordSet,
  );
  @override
  void $set(Userinfo o) {
    _username = o._username;
    _password = o._password;
    _passwordSet = o._passwordSet;
  }

  @override
  List<Object?> get $fields => [_username, _password, _passwordSet];
  @override
  List<String> get $fieldNames => const ['username', 'password', 'passwordSet'];
  @override
  List<String> get $fieldTypes => const ['string', 'string', 'bool'];

  /// `Username()`: "" no nil.
  Golang.String username() => $nilPtr ? Golang.String() : _username;

  /// `Password()`: a senha e se ela foi definida.
  (Golang.String, bool) password() =>
      $nilPtr ? (Golang.String(), false) : (_password, _passwordSet);

  /// `String()`: `user:senha` escapados (sem `@`); "" no nil.
  @override
  Golang.String string() {
    if ($nilPtr) return Golang.String();
    var s = _escape(_username, _encodeUserPassword);
    if (_passwordSet) {
      s += _gs(':') + _escape(_password, _encodeUserPassword);
    }
    return s;
  }
}

/// `User(username)`.
Userinfo user(Golang.String username) => Userinfo(username: username);

/// `UserPassword(username, password)`.
Userinfo userPassword(Golang.String username, Golang.String password) =>
    Userinfo(username: username, password: password, passwordSet: true);
