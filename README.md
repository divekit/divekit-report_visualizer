# Divekit Report Visualizer

A component of divekit used to create a visualization from test reports.

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

## Usage

```
$ divekit-rv --help
Usage: divekit-rv [arguments] <report-path> <report-path>...
    -c HASH, --commit=HASH           Specifies the displayed commit hash (default: "local")
    -u URI, --commit-url=URI         Specifies the link to the current commit (default: none)
    -t TIME, --commit-time=TIME      Specifies the timestamp of the current commit, in ISO 8601 format (default: current local time)
    -o PATH, --output=PATH           Specifies the path to deploy to (default: "public")
    -h, --help                       Show this help
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
