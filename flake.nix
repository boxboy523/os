{
  description = "KZD-OS: Kitten-Zig Distributed OS (ARM64)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            zig
            zls
            gdb
            qemu
            llvmPackages_18.clang-unwrapped
            llvmPackages_18.lld
            llvmPackages_18.lldb
            vscode-extensions.vadimcn.vscode-lldb.adapter
            wasm-tools
            wabt
          ];

          shellHook = ''
            # 1. QEMU 패키지에 내장된 ARM64 펌웨어 먼저 확인
            export QEMU_EFI_ARM=$(find ${pkgs.qemu} -name "edk2-aarch64-code.fd" | head -n 1)

            # 2. 만약 없다면 OVMFFull의 바이너리 경로 확인
            if [ -z "$QEMU_EFI_ARM" ]; then
                export QEMU_EFI_ARM=$(find ${pkgs.OVMFFull.fd} -name "AAVMF_CODE.fd" | head -n 1)
            fi

            echo "🍎 KZD-OS ARM64 Environment Loaded"
            if [ -n "$QEMU_EFI_ARM" ]; then
              echo "✅ UEFI Firmware Found: $QEMU_EFI_ARM"
            else
              echo "❌ 여전히 못 찾았습니다. 아래 명령어로 펌웨어를 강제 다운로드하세요:"
              echo "nix-build '<nixpkgs>' -A OVMFFull.fd"
            fi
          '';
        };
      });
}
