{ haskellPackages
, haskell
, pkgs
, nix
, ...
}:

let
  haskellPackages_ = haskellPackages;
  inherit (pkgs) recurseIntoAttrs;
  inherit (pkgs.lib) cleanSource makeBinPath optionalAttrs;
  inherit (haskell.lib) addBuildDepends overrideCabal buildFromSdist doJailbreak;

  inherit (pkgs.haskell.lib) overrideSrc;

  sources = import ./sources.nix;
  gitignoreSource = sources.nix-gitignore;
  inherit (pkgs.callPackage gitignoreSource {}) gitignoreFilterRecursiveSource;
  gitignoreRecursiveSource = gitignoreFilterRecursiveSource (_: _: true);
  src = gitignoreRecursiveSource "" ../.;

  internal = rec {
    inherit pkgs;

    # TODO: upstream the overrides
    haskellPackages = haskellPackages_.extend (self: super:
     optionalAttrs (!super ? servant-conduit) {
      cachix = super.callHackage "cachix" "0.1.2" {};
      cachix-api = super.callHackage "cachix-api" "0.1.0.2" {};
     } // {
      #cachix = super.callCabal2nix "cachix" (sources.cachix + "/cachix") {};

      hercules-ci-api =
        let basePkg = super.callCabal2nix "hercules-ci-api" (src + "/hercules-ci-api") {};
        in
          buildFromSdist basePkg;

      hercules-ci-agent =
        let basePkg = super.callCabal2nix
                   "hercules-ci-agent"
                   (src + "/hercules-ci-agent")
                   {
                     nix-store = nix;
                     nix-expr = nix;
                     nix-main = nix;
                     bdw-gc = pkgs.boehmgc;
                   };
        in
          buildFromSdist (overrideCabal (
            addBuildDepends
              basePkg
              [ pkgs.makeWrapper pkgs.boost pkgs.boehmgc ]
          ) (o: {
            postInstall = o.postInstall or "" + ''
              wrapProgram $out/bin/hercules-ci-agent --prefix PATH : ${makeBinPath [ pkgs.gnutar pkgs.gzip nix ]}
            '';
            passthru = o.passthru // {
              inherit nix;
            };

            # TODO: We had an issue where any overrideCabal would have
            #       no effect on the package, so we inline the
            #       definition of justStaticExecutables here.
            #       Ideally, we'd go back to a call to
            #       justStaticExecutables, or even better,
            #       a separate bin output.
            #
            # begin justStaticExecutables
            enableSharedExecutables = false;
            enableLibraryProfiling = false;
            isLibrary = false;
            doHaddock = false;
            postFixup = "rm -rf $out/lib $out/nix-support $out/share/doc";
            # end justStaticExecutables
          }));

      hercules-ci-agent-test =
        let basePkg = super.callCabal2nix "hercules-ci-agent-test" (cleanSource ../tests/agent-test) {};
        in
          buildFromSdist basePkg;

    });

    hercules-ci-api-swagger = pkgs.callPackage ../hercules-ci-api/swagger.nix { inherit (haskellPackages) hercules-ci-api; };

    tests = recurseIntoAttrs {
      agent-functional-test = pkgs.nixosTest ../tests/agent-test.nix;
    };
  };
in
recurseIntoAttrs {
  inherit (internal.haskellPackages) hercules-ci-agent;
  inherit (internal) hercules-ci-api-swagger;
  inherit (internal) tests;

  # Not traversed for derivations:
  inherit internal;
}
