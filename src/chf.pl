#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Encode;
use Unicode::Normalize;
use File::Copy;

my $args = join(' ', @ARGV);
$args = Encode::decode('utf-8', $args);
$args = Unicode::Normalize::NFC($args);

my $profile = 'Default';
my $history_file = "$ENV{'HOME'}/Library/Application Support/Google/Chrome/$profile/History";
my $history_copy = '/tmp/__alfred_ch_copy__';
my $expire = 60;
my $count = 100;

if ( ! -f $history_file ) {
    die 'Google Chrome history file not found';
}

if ( -f $history_copy ) {
    my $diff = (stat($history_file))[9] - (stat($history_copy))[9];
    if ( $expire < $diff ) {
        copy($history_file, $history_copy);
    }
}
else {
    copy($history_file, $history_copy);
}

sub sql_escape {
    my $word = shift;
    $word =~ s/'/''/g;
    $word =~ s/%/\%/g;
    return $word;
}

sub xml_escape {
    my $str = shift;
    $str =~ s/"/&quot;/g;
    $str =~ s/'/&apos;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s/&/&amp;/g;
    return $str;
}

sub to_xml {
    my $rows = shift;

    my $xml_items = '';
    for my $row (@$rows) {
        my @cols = split '\|', $row;
        my $url = xml_escape(shift @cols);
        my $title = xml_escape(join '', @cols);

        my $favicon_url = $url;
        $favicon_url =~ s/^(https?:\/\/[^\/]+\/).*$/$1favicon.ico/;

        $xml_items .= <<ITEM;
    <item arg="$url" valid="YES" type="default">
        <title>$title</title>
        <subtitle>$url</subtitle>
    </item>
ITEM
    }

    return <<XML;
<?xml version="1.0" encoding="UTF-8"?>
<items>
$xml_items
</items>
XML

}

my @words = map { sql_escape($_) } split(' ', $args);
my @conditions = map { "(url LIKE '%$_%' OR title LIKE '%$_%')" } @words;
push @conditions, "url LIKE 'http%'";
push @conditions, 'hidden = 0';

my $condition = join ' AND ', @conditions;
my $query = "SELECT url, title FROM urls WHERE $condition ORDER BY last_visit_time DESC LIMIT $count;";

my @rows = split "\n", `sqlite3 "$history_copy" "$query"`;

print to_xml(\@rows);
