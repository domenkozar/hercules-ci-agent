{ pkgs, ...}:
let
  tarball = x: pkgs.runCommand "${x.name or "tarball"}.tar.gz" {
    inherit x;
  } ''
    cd $x && tar -c . | gzip -1 >$out
  '';

  testdata = pkgs.runCommand "testdata" {} ''
    set -x
    mkdir -p $out/testdata
    for p in ${./agent-test/testdata}/*; do
      ln -s $p $out/testdata/$(basename $p);
    done
    ln -s ${tarball pkgs.path} $out/testdata/nixpkgs
  '';

  agentStartTimeoutSec = 5 * 60;

in
{
  name = "agent-test";

  nodes = {
    agent = { config, pkgs, lib, ... }: {
      imports = [
        ../module.nix
      ];
      config = {
        services.hercules-ci-agent.enable = true;
        services.hercules-ci-agent.apiBaseUrl = "http://api";
        services.hercules-ci-agent.clusterJoinTokenPath = pkgs.writeText "pretend-agent-token" "";
        services.hercules-ci-agent.concurrentTasks = 4; # Decrease on itest memory problems

        systemd.services.hercules-ci-agent.serviceConfig.StartLimitBurst = lib.mkForce (agentStartTimeoutSec * 10);
        systemd.services.hercules-ci-agent.serviceConfig.RestartSec = lib.mkForce ("100ms");
        virtualisation.diskSize = 2048;
      };
    };
    api = { ... }: {
      networking.firewall.allowedTCPPorts = [80];
      environment.systemPackages = [ pkgs.testSuitePkgs.hercules-ci-agent-packages.internal.haskellPackages.hercules-ci-agent-test ];
    };
  };

  testScript =
    ''
      startAll;

      # Make sure it even starts (if it doesn't start we need to time
      # out, which will take a very long time on current CI)
      $agent->waitForUnit("hercules-ci-agent.service");

      # Run the test code + api
      $api->succeed("(cd ${testdata} && hercules-ci-agent-test >/dev/console 2>/dev/console)");
    '';
}
