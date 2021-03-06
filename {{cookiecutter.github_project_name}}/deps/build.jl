using BinDeps
using CxxWrap
using Xtensor

@BinDeps.setup

build_type = "Release"

jlcxx_cmake_dir         = joinpath(dirname(pathof(CxxWrap)), "..", "deps", "usr", "lib", "cmake", "JlCxx")

xtl_cmake_dir           = joinpath(dirname(pathof(Xtensor)), "..", "deps", "usr", "lib", "cmake", "xtl")
xtensor_cmake_dir       = joinpath(dirname(pathof(Xtensor)), "..", "deps", "usr", "lib", "cmake", "xtensor")
xtensor_julia_cmake_dir = joinpath(dirname(pathof(Xtensor)), "..", "deps", "usr", "lib", "cmake", "xtensor-julia")

julia_bindir            = Sys.BINDIR

prefix                  = joinpath(dirname(@__FILE__), "usr")
extension_srcdir        = joinpath(dirname(@__FILE__), "{{ cookiecutter.cpp_package_name }}")
extension_builddir      = joinpath(dirname(@__FILE__), "..", "builds", "{{ cookiecutter.julia_package_name }}")

# Setup cmake generator
@static if Sys.iswindows()
    genopt = "MinGW Makefiles"
else
    genopt = "Unix Makefiles"
end

# Build on windows: push BuildProcess into BinDeps defaults
@static if Sys.iswindows()
  if haskey(ENV, "BUILD_ON_WINDOWS") && ENV["BUILD_ON_WINDOWS"] == "1"
    saved_defaults = deepcopy(BinDeps.defaults)
    empty!(BinDeps.defaults)
    append!(BinDeps.defaults, [BuildProcess])
  end
end

# Functions library for testing
example_labels = [:examples]
extension = BinDeps.LibraryDependency[]
for l in example_labels
   @eval $l = $(library_dependency(string(l), aliases=["lib" * string(l)]))
   push!(extension, eval(:($l)))
end

extension_steps = @build_steps begin
  `cmake -G "$genopt" -DCMAKE_PREFIX_PATH=$prefix -DCMAKE_INSTALL_PREFIX=$prefix -DCMAKE_BUILD_TYPE="$build_type" -DJlCxx_DIR=$jlcxx_cmake_dir -Dxtl_DIR=$xtl_cmake_dir -Dxtensor_DIR=$xtensor_cmake_dir -Dxtensor-julia_DIR=$xtensor_julia_cmake_dir -DCMAKE_PROGRAM_PATH=$julia_bindir $extension_srcdir`
  `cmake --build . --config $build_type --target install`
end

provides(BuildProcess,
  (@build_steps begin
    println("Building {{ cookiecutter.julia_package_name }}")
    CreateDirectory(extension_builddir)
    @build_steps begin
      ChangeDirectory(extension_builddir)
      extension_steps
    end
  end), extension)

@BinDeps.install Dict([
    (:examples, :_l_examples)
])

# Build on windows: pop BuildProcess from BinDeps defaults
@static if Sys.iswindows()
  if haskey(ENV, "BUILD_ON_WINDOWS") && ENV["BUILD_ON_WINDOWS"] == "1"
    empty!(BinDeps.defaults)
    append!(BinDeps.defaults, saved_defaults)
  end
end
