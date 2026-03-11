{
  description = "KZD-OS: Kitten-Zig Distributed OS development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # 1. 지원되지 않는 시스템(RISC-V) 빌드를 허용하도록 설정된 pkgs 생성
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnsupportedSystem = true;
          };
        };

        # 2. RISC-V 64비트 교차 컴파일용 패키지 셋 정의
        pkgsRiscv = pkgs.pkgsCross.riscv64;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            zig
            zls
            qemu
            gdb
            lldb
            xorriso
            grub2
            # 3. 교차 컴파일된 패키지 셋에서 U-Boot를 가져옵니다.
            pkgsRiscv.ubootQemuRiscv64Smode
          ];

          shellHook = ''
            # 4. U-Boot 바이너리 경로를 환경 변수로 자동 등록
            export UBOOT_BIN="${pkgsRiscv.ubootQemuRiscv64Smode}/u-boot.bin"

            echo "🍎 KZD-OS Development Environment Loaded"
            echo "Zig version: $(zig version)"
            echo "U-Boot Path: $UBOOT_BIN"
          '';
        };
      });
}
