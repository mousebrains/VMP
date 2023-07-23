# This code is designed to take Rockland Scientific Vertical Turbulence Profilers *(VMP)* `.P` files and transform them into binned cast files.

Hopefully, everything is parameterized and one just needs to call `processVMPfiles` with the appropriatep [Parameters.md](parameters.)

The data flow is:
- New/updated `.P` files are transformed into .mat files using `odas_p2mat`
- New/updated `.mat` files are split into profiles and saved into profiles `.mat` files
- New/updated profile `.mat` files are binned and saved into binned `.mat` files
- New/updated binned `.mat` files are combined togeter into a `combo.mat` file.

The `.P` files are expected to be in directories like `SN142/*.p` Then the outputs are saved into a similar structure.

The profiles and binned directories have a hash attached to their name which is unique to the input parameters. If you change any parameter, a new directory try will probably be generated.
