# Divekit Report Visualizer

A component of divekit used to visualize test reports.

## Installation

For compiling, you will need the `crystal` compiler and the `shards` dependency manager.

Just execute the following command:  
```bash
shards build --release --production
```

Optionally, you can add the `-Dno_minify` compile-time flag to prevent minifying the output:
```bash
shards build --release --production --Dno_minify
```

After running any of these commands, the `divekit-rv` tool should be located inside the `bin/` directory.

## Usage

`divekit-rv` works using a context-based cli.

Directly behind the binary name, you can specify global arguments.

Once you specify a non-option argument (like a file path), a new context is opened.

To see which report types are supported in your build
and what options they support, use the `--help` option:

```
$ divekit-rv --help
Divekit Report Visualizer v0.1.0
Usage: divekit-rv [global arguments] <report-path> [report arguments] <report-path> [report arguments] ...

Global arguments (affects whole program instead of just one file):
  -c HASH, --commit=HASH           Specifies the displayed commit hash (default: "local")
  -u URI, --commit_url=URI         Specifies the link to the current commit (default: none)
  -o PATH, --output=PATH           Specifies the path to deploy to (default: "public")
  -t TIME, --commit_time=TIME      Specifies the timestamp of the current commit, in ISO 8601 format (default: current local time)
  -h, --help                       Show this help

Custom-Report ("*.custom-test.json") arguments:
  None

PMD-Report ("*.pmd.json") arguments:
  --category=NAME                  Specifies the category the PMD report is put in (default: "PMD")
  --split_rules=RULE1,RULE2,...    Splits this report into one report for each specified rule

Surefire-Report ("TEST-*.xml") arguments:
  None
```

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/divekit/divekit-report_visualizer/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [David Keller](https://github.com/BlobCodes) - creator and maintainer
