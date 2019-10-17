{ stdenvNoCC
, makeWrapper
, coreutils
, enableX11 ? true
, xsel ? null
, enableWayland ? true
, wl-clipboard ? null
}: with stdenvNoCC.lib;

assert enableX11 -> xsel != null;
assert enableWayland -> wl-clipboard != null;

stdenvNoCC.mkDerivation {
  pname = "clip";
  version = "0.0.1"; # idk

  preferLocalBuild = true;

  src = ./clip.sh;

  nativeBuildInputs = [ makeWrapper ];

  wrappedPath = makeSearchPath "bin" ([ coreutils ]
    ++ optional enableX11 xsel
    ++ optional enableWayland wl-clipboard
  );

  buildCommand = ''
    mkdir -p $out/bin
    makeWrapper $src $out/bin/$pname \
      --prefix PATH : $wrappedPath
  '';
}
