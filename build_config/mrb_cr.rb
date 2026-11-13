# mruby build configuration for mrb.cr.
#
# Only the interpreter core and the compiler are required by the binding.
# Host applications that need more (IO, sockets, time) should build their own
# gembox; this configuration keeps the linked surface small and auditable.
MRuby::Build.new do |conf|
  conf.toolchain

  conf.gem core: "mruby-compiler"
  conf.gem core: "mruby-error"

  # Static libraries should be position independent so hosts can link them
  # into shared objects on ELF platforms. MSVC does not understand -fPIC.
  conf.cc.flags << "-fPIC" unless conf.cc.command =~ /\bcl(\.exe)?\b/i
end
