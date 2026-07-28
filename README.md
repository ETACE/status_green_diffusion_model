# Dual Status Signaling and the Diffusion of Green Innovation

Version: July 2026

This agent-based model examines how status signaling shapes the diffusion of sustainable technologies in a heterogeneous consumer-firm setting.

## Getting Started

These instructions will allow you to run the model on your system.

### System Requirements and Installation

To run the code, you need to install **[Julia](https://julialang.org/)** (v1.12.6). Additionally, the following packages need to be installed:


* [Agents](https://juliadynamics.github.io/Agents.jl/stable/) - Version 7.0.3
* [ArgParse](https://argparsejl.readthedocs.io/en/latest/argparse.html) - Version 1.2.0
* [CSV] (https://csv.juliadata.org/stable/) - Version 0.10.16
* [Colors] (https://juliagraphics.github.io/Colors.jl/stable/) - Version 0.13.1
* [DataFrames](https://juliadata.github.io/) - Version 1.8.2
* [Dates] (https://docs.julialang.org/en/v1/stdlib/Dates/) - Version 1.11.0
* [DataStructures](https://juliacollections.github.io/DataStructures.jl/latest/) - Version 0.18.22
* [Distributed] (https://github.com/JuliaLang/Distributed.jl) - Version 1.11.0
* [Distributions] (https://juliastats.org/Distributions.jl/stable/) - Version 0.25.130
* [LinearAlgebra] (https://docs.julialang.org/en/v1/stdlib/LinearAlgebra/) - Version 1.12.0
* [LsqFit](https://julianlsolvers.github.io/LsqFit.jl/latest/tutorial/) - Version 0.16.1
* [Random](https://docs.julialang.org/en/v1/stdlib/Random/#Random.Random) - Version 1.11.0
* [Plots](http://docs.juliaplots.org/) - Version 1.41.6
* [Serialization] (https://docs.julialang.org/en/v1/stdlib/Serialization/) - Version 1.11.0
* [SkipNan] (https://alexriss.github.io/SkipNan.jl/stable/) - Version 0.2.0
* [Statistics](https://docs.julialang.org/en/v1/stdlib/Statistics/) - Version 1.11.1
* [StatsBase] (https://github.com/JuliaStats/StatsBase.jl) - Version 0.33.21
* [StatsPlots](https://github.com/JuliaPlots/StatsPlots.jl) - Version 0.15.8
* [TensorCast] (https://juliapackages.com/p/tensorcast) - Version 0.4.9



To install a package, start *julia* and execute the following command:

```
using Pkg; Pkg.add("<package name>")
```

### Running The Model

The model implementation is located in the *model/* folder. To run the model, the initial state must be set up. Our baseline initialization is specified in the *experiments/initialization.jl* file. By default, the subset of data stored during a simulation run is defined in the *experiments/data_collection.jl* file.

To conduct an experiment and execute several runs of the model (batches) in parallel, execute *run_exp.jl*. This requires setting up the experiment(s) in a configuration file; see *baseline.jl* as an example. To execute an experiment, use the following command:

```
julia [--project=<path>] [-p <no_cpus>] run_exp.jl <config-file> [--chunk <i>] [--no_chunks <n>]
```

Instead of using activate from within Julia, you can specify the project on startup using the --project=<path> flag. For example, to run a script from the command line using the environment in the current directory, you can run

```
julia --project=. [-p <no_cpus>] run_exp.jl <config-file> [--chunk <i>] [--no_chunks <n>]
```

The Julia parameter *-p <no_cpus>* is optional and specifies how many CPU cores will be used in parallel. The *--chunk* and *--no_chunk* parameters are also optional and can be used to break up the experiment into several chunks, e.g., to distribute execution among different machines.

Plots from experiments can be created by using the following command:

```
julia plot_exp.jl <config-file>
```

By default, data and plots will be stored in the *data/* and *plots/* folders, respectively.

## Authors

Fiona Borsetzky, Isabella Koch

## Further Links

* [ETACE](https://www.uni-bielefeld.de/fakultaeten/wirtschaftswissenschaften/lehrbereiche/etace/) - Economic Theory and Computational Economics, Bielefeld University
