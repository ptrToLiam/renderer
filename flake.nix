{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zig.url = "github:mitchellh/zig-overlay";
  };

  outputs = { self, nixpkgs, zig }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });
    in
    {
      devShells = forEachSupportedSystem({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            inotify-tools
            lldb
            libinput
            libxkbcommon
            man-pages
            mesa
            pkg-config
            renderdoc
            shaderc
            shader-slang
            valgrind
            vulkan-loader
            vulkan-tools
            vulkan-headers
            vulkan-tools-lunarg
            vulkan-validation-layers
            vulkan-extension-layer
            #zig.packages.${system}."master-2026-02-03"
          ];
          shellHook = ''
            RPATH="${pkgs.vulkan-loader}/lib:${pkgs.libxkbcommon}/lib"
            export VK_LAYER_PATH="${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d"
          '';
        };
      });
    };
}
