# `divekit-rv` Hacking Guide

Hello and thanks for wanting to contribute to this project!

`divekit-rv` is the component in divekit responsible for visualizing test reports.

If, during development, you find out something which would be good for other developers to know, feel free to add it to this document.

## Project structure

First of all, there is a hard split between the template and the main processing.

The CLI, report parsing and general preprocessing resides inside the `src/` directory while any static files or template files meant for generating the user-facing report are inside the `template` directory.
All user-facing text must be stored inside the `template` directory.

```
divekit-rv
├── src
│   ├── macros
│   │   └── ... (macros)
│   ├── report
│   │   ├── report.cr
│   │   └── ... (reports)
│   └── app.cr
└── template
    ├── style.css, index.html, ... (static files)
    ├── 
    └── %style-slot.css, %slot2.ecr, ... (Slot imports)
```

## Template structure

The template must be located inside the `template/` directory.
An explanation of the templating engine will follow this paragraph,
but please note that the templating engine may be replaced later.
There are multiple issues with it, addressed in issue #14.

Templates consist of static files and template files (in original and minified versions).

While static files (directly inside `template/`) are just copied as-is to the output directory, template files are in `.ecr` format which allows them to execute arbitrary crystal code. For more information about the ECR format, please visit https://crystal-lang.org/api/latest/ECR.html.

For each `.ecr` (or `.min.ecr`) file directly inside `template/`, an output file is generated with the output of the evaluated template.

Besides the template root, `.ecr` files also appear inside `template/reports/`.  
Here, the template parts directly related to specific report types are stored.
The content of these files is very similar to the template root `.ecr` files, with the exception that the templates are executed from within the reports.
This means that instance variables of the reports can directly be accessed.  
These `.ecr` files are not rendered into an output file. They are used to define the `#render` instance method of the report subtypes.

## Command line interface

The command-line interface of divekit-rv has been mostly inspired by ffmpeg.
It is a context-based CLI - all flags given to the program are associated with the last non-flag argument given.

This example explains the CLI a bit better:
```bash
  divekit-rv                                                        \
    --output ./dist                                                 \
    --commit_url "http://example.com"                               \
`#  ^ These two arguments above are passed to the "global state". ` \
`#    They can only be given before any file was specified.       ` \
                                                                    \
    ./TEST-thkoeln.exampes.Test01.xml                               \
      --category "Test category"                                    \
`#    ^ The category flag is passed to the report subclass during ` \
`#      its initialization. Here, it overwrites the category.     ` \
                                                                    \
    ./export.pmd.json                                               \
      --category "Another category"                                 \
      --default-report ""                                           \
      --split "ExcessivePublicCount:Open Closed Principle"          \
`#    ^ These three flags are now completely separate from the    ` \
`#      report above. They are not inherited or stored otherwise. `
```

Note that command-line arguments are always validated instantly.  
For example if a PMD report with the name `export.pmd.json` was given a flag `--does-not-exist=true`, the visualizer would immediately panic once it were read.  

To support this immediate validation, the type of a report may only be determined using its filename. 
This requires additional attention when configuring a milestone, as bad wildcards can cause the visualizer to fail if reports could not be generated.

---

In the main code, `Report` subclasses handle the command line parsing by automatically including multiple interfaces in their meta-class (`CLI::Context` and `Report::ReportClass`).

`Report` subclasses can:
- Define a pattern to detect their reports using the filename.
- Define which flags they accept using the `option` macro.

This is a template to showcase these macros in action:
```crystal
# Example report (Only CLI-related parts included)
class Report::Example < Report
  # A class-variable to store a flag
  @@example_flag : String?

  # The "patterns" macro allows passing a glob
  # to specify how files must be named to be
  # associated with this report type.
  patterns "example-*.mp3"

  option "--flag=VALUE", "Example flag" do |value|
    # If this block is called, the flag and
    # the value of it was successfully read.

    # We can store this value in a class-variable
    # to process it later, when reading the report. 
    @@example_flag = value
  end

  option "--print-hello", "Prints hello" do
    # Flags can also have no arguments.

    puts "Hello!"
  end

  def self.init_context : Nil
    # This class-method is called once a file
    # with the pattern given above was found.
    # Here we must reset the state of this class.

    @@example_flag = nil
  end

  def self.from_path(path : Path) : Enumerable(Report)
    # Instantiation of the reports.
    # Here we can use the data collected from the flags.

    raise NotImplementedError.new("Not implemented")
  end
end
```

## Releases and versioning

The report visualizer's releases adhere to [Semanic Versioning 2.0.0](https://semver.org/).

The binaries attached to new releases are automatically generated using GitHub CI.
