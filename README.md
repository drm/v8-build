# Containerized v8 monolith build

This is a utility script to build the v8 monolith in a container.

Based on [https://v8.dev/docs/embed](https://v8.dev/docs/embed)

## Usage

```
./build.sh VERSION [STAGES...]
```

where VERSION is the v8 version you want to build. Checkout the tag list in the
[github.com/v8/v8](https://github.com/v8/v8) repository to see what the latest
is (which is what you'd typically want).

STAGES lets you control the different stages of the build, which is typically
only needed if you need to debug the build. Read the script source code for
more information.

Running a successful build should render a directory named 'out' containing 
`icudtl.dat` and `libv8_monolith.a`.

## Issues? Need help?

Feel free to drop me a note.

## License

You are free to use this piece of software as you please, as long as you 
realize there are no guarantees, whatsoever.
