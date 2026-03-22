((zig-mode . ((dape-configs . ((wasm-debug
                                 command "codelldb"
                                 :type "lldb"
                                 :request "launch"
                                 :program "./zig-out/bin/wasm-engine"
                                 :cwd "."
                                 :args ["test.wasm"]))))))
