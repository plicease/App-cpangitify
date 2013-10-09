use strict;
use warnings;
use File::HomeDir::Test;
use File::HomeDir;
use Test::More tests => 13;
use App::cpan2git;
use Capture::Tiny qw( capture_merged );
use File::chdir;
use URI::file;
use Path::Class qw( file dir );

my $home = dir( File::HomeDir->my_home );

do {
  local $CWD = "$home";
  my $ret;
  
  my @args = (
    '--backpan_index_url' => "file://localhost/home/ollisg/dev/App-cpan2git/t/backpan/backpan-index.txt.gz",
    '--backpan_url'       => "file://localhost/home/ollisg/dev/App-cpan2git/t/backpan",
    'Foo::Bar',
  );
  
  my $merged = capture_merged { $ret = App::cpan2git->main(@args) };
  is($ret, 0, "% cpan2git @args");
  note $merged;
};

my $git = Git::Wrapper->new($home->subdir('Foo-Bar')->stringify);

my @commits = $git->log;

like $commits[0]->message, qr{^version 0\.03$}, "commits.0.message = version 0.03";
like $commits[1]->message, qr{^version 0\.02$}, "commits.1.message = version 0.02";
like $commits[2]->message, qr{^version 0\.01$}, "commits.2.message = version 0.01";

foreach my $commit (@commits)
{
  like $commit->date, qr{^Wed Oct 9 .* 2013}, "commit.date = " . $commit->date;
  is $commit->author, 'Reserved Local Account <adam@ali.as>', 'commit.author = ' . $commit->author;
}

# 0.03
my @yes = map { [ split /\// ] } qw( lib/Foo/Bar.pm lib/Foo/Bar/Baz.pm t/use.t );
my @no  = map { [ split /\// ] } qw( t/stuffit.t );
check(0.03);

# 0.02
@yes = map { [ split /\// ] } qw( lib/Foo/Bar.pm lib/Foo/Bar/Baz.pm t/use.t t/stuffit.t );
@no  = map { [ split /\// ] } qw( );
check(0.02);

# 0.01
@yes = map { [ split /\// ] } qw( lib/Foo/Bar.pm t/use.t );
@no  = map { [ split /\// ] } qw( t/stuffit.t lib/Foo/Bar/Baz.pm );
check(0.01);

sub check
{
  my $tag = shift;
  $git->checkout($tag);
  subtest "version $tag" => sub {
    plan tests => @yes + @no;
    
    foreach my $file (map { $home->file('Foo-Bar', @$_) } @yes)
    {
      ok -e $file, "exists $file";
    }
    
    foreach my $file (map { $home->file('Foo-Bar', @$_) } @no)
    {
      ok !-e $file, "does not exists $file";
    }
  };
}
