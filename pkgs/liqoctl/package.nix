{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
}:

# Bump: take version from https://github.com/liqotech/liqo/releases,
# then src hash and vendorHash.
buildGoModule (finalAttrs: {
  pname = "liqoctl";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "liqotech";
    repo = "liqo";
    tag = "v${finalAttrs.version}";
    hash = "sha256-F1094PW0F8UMEEswbPxxliVVyg1QcBfT26idy56bUU0=";
  };

  vendorHash = "sha256-yawl4KEvPDrUi8DAGfOiMSdzWsIfQuqAtMEUbQe5nO0=";

  subPackages = [ "cmd/liqoctl" ];

  env.CGO_ENABLED = "0";

  ldflags = [
    "-s"
    "-w"
    "-X github.com/liqotech/liqo/pkg/liqoctl/version.LiqoctlVersion=v${finalAttrs.version}"
  ];

  nativeBuildInputs = [ installShellFiles ];

  postInstall = ''
    export HOME="$(mktemp -d)"
    installShellCompletion --cmd liqoctl \
      --bash <($out/bin/liqoctl completion bash) \
      --fish <($out/bin/liqoctl completion fish) \
      --zsh <($out/bin/liqoctl completion zsh)
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$(mktemp -d)"
    $out/bin/liqoctl version --client | grep -F "v${finalAttrs.version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "CLI to install and manage Liqo-enabled Kubernetes clusters";
    homepage = "https://github.com/liqotech/liqo";
    changelog = "https://github.com/liqotech/liqo/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "liqoctl";
  };
})
