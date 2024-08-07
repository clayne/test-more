# This file is generated by Dist::Zilla::Plugin::CPANFile v6.032
# Do not edit this file directly. To change prereqs, edit the `dist.ini` file.

requires "B" => "0";
requires "Data::Dumper" => "0";
requires "Exporter" => "0";
requires "File::Spec" => "0";
requires "File::Temp" => "0";
requires "Scalar::Util" => "1.13";
requires "Storable" => "0";
requires "Term::Table" => "0.013";
requires "Time::HiRes" => "0";
requires "overload" => "0";
requires "perl" => "5.006002";
requires "utf8" => "0";
suggests "Module::Pluggable" => "2.7";
suggests "Term::ReadKey" => "0";
suggests "Term::Size::Any" => "0";
suggests "Unicode::GCString" => "0";
suggests "Unicode::LineBreak" => "0";

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "IPC::Open3" => "0";
  requires "Term::Table" => "0.013";
  requires "Test::Pod" => "1.41";
  requires "Test::Spelling" => "0.12";
};
