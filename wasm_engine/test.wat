(module $test.wasm
  (type (;0;) (func (param i32 i32) (result i32)))
  (func $add (type 0) (param i32 i32) (result i32)
    local.get 1
    local.get 0
    i32.add)
  (memory (;0;) 16)
  (global $__stack_pointer (mut i32) (i32.const 1048576))
  (export "memory" (memory 0))
  (export "add" (func $add)))
🍎 KZD-OS Development Environment Loaded
Zig version: 0.15.2
U-Boot Path: /nix/store/17amimgwxlrwqikzb5ayblb52iinx9zd-uboot-qemu-riscv64_smode_defconfig-riscv64-unknown-linux-gnu-2025.10/u-boot.bin
(module $test.wasm
  (type (;0;) (func (param i32 i32) (result i32)))
  (func $add (type 0) (param i32 i32) (result i32)
    local.get 1
    local.get 0
    i32.add)
  (memory (;0;) 16)
  (global $__stack_pointer (mut i32) (i32.const 1048576))
  (export "memory" (memory 0))
  (export "add" (func $add)))
