module JuliaActuarySite

using PlutoStaticHTML

const PKGDIR = pkgdir(JuliaActuarySite)

export build_notebooks

const TUTORIALS_DIR = joinpath(PKGDIR, "tutorials")

"Get files from a previous run. Assumes that the files are inside a `gh-pages` branch."
function prev_dir()::Union{Nothing,AbstractString}
    if "DISABLE_CACHE" in keys(ENV) && ENV["DISABLE_CACHE"] == "true"
        return nothing
    end
    if !("REPO" in keys(ENV))
        return nothing
    end
    repo = ENV["REPO"]
    url = "https://github.com/$repo"
    dir = mktempdir()
    @info "Cloning $(url)#gh-pages for caching purposes"
    try
        # This can fail if there is no gh-pages branch yet.
        run(`git clone --depth=1 --branch=gh-pages $url $dir`)
        prev_dir = joinpath(dir, "tutorials")
        return prev_dir
    catch
        return nothing
    end
end

"Build all the notebooks in parallel."
function build()
    dir = TUTORIALS_DIR
    output_format = franklin_output
    previous_dir = prev_dir()
    bopts = BuildOptions(dir; output_format, previous_dir)
    hopts = HTMLOptions(; append_build_context=true,
    code_class="julia hljs pluto-input",
    output_pre_class="pluto-output",
    )
    PlutoStaticHTML.build_notebooks(bopts, hopts)
    return nothing
end

"Add a link to the notebook at the bottom of each tutorial."
function append_notebook_links()
    dir = TUTORIALS_DIR
    md_paths = filter(endswith(".md"), readdir(dir; join=true))
    for md_path in md_paths
        md_file = basename(md_path)
        without_extension, _ = splitext(md_file)
        if isfile(replace(md_path,"md"=>"jl"))
            jl_file = "$(without_extension).jl"
            url = "/tutorials/$jl_file"
            open(md_path, "a") do io
                text = """\n
                    ## Run this Pluto Notebook
                    
                    _To run this page locally, download [this file]($url) and open it with
                    [Pluto.jl](https://plutojl.org)._

                    ~~~

                    <link rel="stylesheet" href="/libs/highlight/github.min.css">
                    <script src="/libs/highlight/highlight.min.js"></script>
                    <script>hljs.highlightAll();</script>
                    
                    ~~~
                    """
                write(io, text)
            end
        end
    end
    return nothing
end

"Copy the source Markdown files, so that they can be inspected for debugging and used with caching."
function copy_markdown_files()
    from_dir = TUTORIALS_DIR
    md_files = filter(endswith(".md"), readdir(from_dir))
    to_dir = joinpath(PKGDIR, "__site", "tutorials")
    mkpath(to_dir)
    for md_file in md_files
        from = joinpath(from_dir, md_file)
        to = joinpath(to_dir, md_file)
        cp(from, to; force=true)
    end
    return nothing
end

function is_Pluto_notebook(filepath)
   lines = eachline(filepath)
   return first(lines) == "### A Pluto.jl notebook ###" 
end

"Build the tutorials."
function build_notebooks()
    build()
    # Copy the Markdown first or the appended notebook links will add up.
    copy_markdown_files()
    append_notebook_links()
end
precompile(build_notebooks, ())

end # module