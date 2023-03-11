#==
- Cell controls
- Directory cells
- Session cells (markdown, code)
- REPL Cells
==#
function cell_up!(c::Connection, cm2::ComponentModifier, cell::Cell{<:Any},
    cells::Vector{Cell{<:Any}}, windowname::String)
    pos = findall(lcell -> lcell.id == cell.id, cells)[1]
    if pos != 1
        switchcell = cells[pos - 1]
        originallen = length(cells)
        cells[pos - 1] = cell
        println(switchcell)
        cells[pos] = switchcell
        remove!(cm2, "cellcontainer$(switchcell.id)")
        remove!(cm2, "cellcontainer$(cell.id)")
        ToolipsSession.insert!(cm2, windowname, pos - 1, build(c, cm2, switchcell, cells,
        windowname))
        ToolipsSession.insert!(cm2, windowname, pos - 1, build(c, cm2, cell, cells,
        windowname))
        focus!(cm2, "cell$(cell.id)")
    else
        olive_notify!(cm2, "this cell cannot go up any further!", color = "red")
    end
end

function cell_down!(c::Connection, cm::ComponentModifier, cell::Cell{<:Any},
    cells::Vector{Cell{<:Any}}, windowname::String)
    pos = findall(lcell -> lcell.id == cell.id, cells)[1]
    if pos != length(cells)
        switchcell = cells[pos + 1]
        cells[pos + 1] = cell
        cells[pos] = switchcell
        remove!(cm, "cellcontainer$(switchcell.id)")
        remove!(cm, "cellcontainer$(cell.id)")
        ToolipsSession.insert!(cm, windowname, pos, build(c, cm, switchcell, cells,
        windowname))
        ToolipsSession.insert!(cm, windowname, pos + 1, build(c, cm, cell, cells,
        windowname))
        focus!(cm, "cell$(cell.id)")
    else
        olive_notify!(cm, "this cell cannot go down any further!", color = "red")
    end
end

function cell_delete!(c::Connection, cm::ComponentModifier, cell::Cell{<:Any},
    cells::Vector{Cell{<:Any}})
    remove!(cm, "cellcontainer$(cell.id)")
    deleteat!(cells, findfirst(c -> c.id == cell.id, cells))
end

function cell_new!(c::Connection, cm::ComponentModifier, cell::Cell{<:Any},
    cells::Vector{Cell{<:Any}}, windowname::String; type::String = "code")
    pos = findall(lcell -> lcell.id == cell.id, cells)[1]
    newcell = Cell(pos, type, "")
    insert!(cells, pos + 1, newcell)
    ToolipsSession.insert!(cm, windowname, pos + 1, build(c, cm, newcell,
    cells, windowname))
end

function bind!(c::Connection, cell::Cell{<:Any}, cells::Vector{Cell},
    windowname::String, exclude::Symbol ...)
    keybindings = c[:OliveCore].client_data[getip(c)]["keybindings"]
    km = ToolipsSession.KeyMap()
    bind!(km, keybindings[:up] ...) do cm2::ComponentModifier
        cell_up!(c, cm2, cell, cells, windowname)
    end
    bind!(km, keybindings[:down] ...) do cm2::ComponentModifier
        cell_down!(c, cm2, cell, cells, windowname)
    end
    bind!(km, keybindings[:delete] ...) do cm2::ComponentModifier
        cell_delete!(c, cm2, cell, cells)
    end
    bind!(km, keybindings[:new] ...) do cm2::ComponentModifier
        cell_new!(c, cm2, cell, cells, windowname)
    end
    bind!(km, keybindings[:evaluate] ...) do cm2::ComponentModifier
        evaluate(c, cm, cell, windowname)
    end
    km::KeyMap
end

function bind!(c::Connection, cell::Cell{<:Any}, d::Directory{<:Any};
    explorer::Bool = false)

end

"""
**Interface**
### build(c::Connection, cell::Cell{<:Any}, d::Directory{<:Any}; explorer::Bool = false) -> ::Component{:div}
------------------
The catchall/default `build` function for directory cells. This function is what
creates the gray boxes for files that Olive cannot read inside of directories.
Using this function as a template, you can create your own directory cells.
Write a new method for this function in order to build cells for a new
file type. Note that you might also want to extend `olive_save` in order
to save your new file type. Bind `dblclick` and use the `load_session` or
`add_to_session` methods, dependent on `explorer`... Which should also be `false`
by default. `directory_cells` will put the file path into `cell.outputs` and
the file name into `cell.source`.
#### example
```
using Olive
using Toolips
using ToolipsSession
import Olive: build

function build(c::Connection, cell::Cell{:txt}, d::Directory{<:Any}; explorer::Bool = false)
    # build base cell
    hiddencell = div("cell\$(cell.id)")
    style!(hiddencell, "background-color" => "white")
    name = a("cell\$(cell.id)label", text = cell.source)
    style!(name, "color" => "black")
    push!(hiddencell, name)
    # bind events
    if explorer
        on(c, hiddencell, "dblclick") do cm::ComponentModifier
            txt = read(cell.outputs, String)
            # you might want to make a build function for this cell :)
            newcell = Olive.Cell(1, "txt", txt)
            cells = [newcell]
            Olive.add_to_session(c, cells, cm, cell.source, cell.outputs)
        end
    else
        on(c, hiddencell, "dblclick") do cm::ComponentModifier
            txt = read(cell.outputs, String)
            newcell = Olive.Cell(1, "txt", txt)
            cells = [newcell]
            Olive.load_session(c, cells, cm, cell.source, cell.outputs)
        end
    end
    hiddencell
end
```
Here are some other **important** functions to look at for creating cells:
-
"""
function build(c::Connection, cell::Cell{<:Any}, d::Directory{<:Any};
    explorer::Bool = false)
    hiddencell = div("cell$(cell.id)", class = "cell-hidden")
    name = a("cell$(cell.id)label", text = cell.source)
    style!(name, "color" => "black")
    push!(hiddencell, name)
    hiddencell
end

function build_base_cell(c::Connection, cell::Cell{<:Any}, d::Directory{<:Any};
    explorer::Bool = false)

end


function build(c::Connection, cell::Cell{:ipynb},
    d::Directory{<:Any}; explorer::Bool = false)
    filecell = div("cell$(cell.id)", class = "cell-ipynb")
    if explorer
        on(c, filecell, "dblclick") do cm::ComponentModifier
            cs::Vector{Cell{<:Any}} = IPyCells.read_ipynb(cell.outputs)
            add_to_session(c, cs, cm, cell.source, cell.outputs)
        end
    else
        on(c, filecell, "dblclick") do cm::ComponentModifier
            cs::Vector{Cell{<:Any}} = IPyCells.read_ipynb(cell.outputs)
            load_session(c, cs, cm, cell.source, cell.outputs, d)
        end
    end
    fname = a("$(cell.source)", text = cell.source)
    style!(fname, "color" => "white", "font-size" => 15pt)
    push!(filecell, fname)
    filecell
end

function olive_save(cells::Vector{<:IPyCells.AbstractCell}, sc::Cell{<:Any})
    IPyCells.save(cells, sc.outputs)
end

function dir_returner(c::Connection, cell::Cell{<:Any}, d::Directory{<:Any};
    explorer::Bool = false)
    returner = div("cell$(cell.id)", class = "cell-jl")
    style!(returner, "background-color" => "red")
    name = a("cell$(cell.id)label", text = "...")
    style!(name, "color" => "white")
    push!(returner, name)
    on(c, returner, "dblclick") do cm2::ComponentModifier
        newcells = directory_cells(d.uri)
        n_dir::String = d.uri
        built = [build(c, cel, d, explorer = explorer) for cel in newcells]
        if typeof(d) == Directory{:subdir}
            n_dir = d.access["toplevel"]
            if n_dir != d.uri
                newd = Directory(n_dir, "root" => "rw",
                "toplevel" => d.access["toplevel"], dirtype = "subdir")
                insert!(built, 1, dir_returner(c, cell, newd))
            end
        end
        becell = replace(n_dir, "/" => "|")
        nbcell = replace(d.uri, "/" => "|")
        cm2["$(becell)cells"] = "sel" => nbcell
        set_children!(cm2, "$(becell)cells",
        Vector{Servable}(built))
    end
    returner::Component{:div}
end

function build(c::Connection, cell::Cell{:dir}, d::Directory{<:Any};
    explorer::Bool = false)
    filecell = div("cell$(cell.id)", class = "cell-ipynb")
    style!(filecell, "background-color" => "#FFFF88")
    on(c, filecell, "dblclick") do cm::ComponentModifier
        returner = dir_returner(c, cell, d, explorer = explorer)
        nuri::String = "$(d.uri)/$(cell.source)"
        newcells = directory_cells(nuri)
        becell = replace(d.uri, "/" => "|")
        nbecell = replace(nuri, "/" => "|")
        cm["$(becell)cells"] = "sel" => nbecell
        toplevel = d.uri
        if typeof(d) == Directory{:subdir}
            toplevel = d.access["toplevel"]
        end
        nd = Directory(d.uri * "/" * cell.source * "/", "root" => "rw",
        "toplevel" => toplevel, dirtype = "subdir")
        set_children!(cm, "$(becell)cells",
        Vector{Servable}(vcat([returner],
        [build(c, cel, nd, explorer = explorer) for cel in newcells])))
    end
    fname = a("$(cell.source)", text = cell.source)
    style!(fname, "color" => "gray", "font-size" => 15pt)
    push!(filecell, fname)
    filecell
end

function build(c::Connection, cell::Cell{:jl},
    d::Directory{<:Any}; explorer::Bool = false)
    hiddencell = div("cell$(cell.id)", class = "cell-jl")
    style!(hiddencell, "cursor" => "pointer")
    if explorer
        on(c, hiddencell, "dblclick") do cm::ComponentModifier
            cs::Vector{Cell{<:Any}} = IPyCells.read_jl(cell.outputs)
            add_to_session(c, cs, cm, cell.source, cell.outputs)
        end
    else
        on(c, hiddencell, "dblclick") do cm::ComponentModifier
            cs::Vector{Cell{<:Any}} = IPyCells.read_jl(cell.outputs)
            load_session(c, cs, cm, cell.source, cell.outputs, d)
        end
    end
    name = a("cell$(cell.id)label", text = cell.source)
    style!(name, "color" => "white")
    push!(hiddencell, name)
    hiddencell
end

function build(c::Connection, cell::Cell{:toml},
    d::Directory; explorer::Bool = false)
    hiddencell = div("cell$(cell.id)", class = "cell-toml")
    name = a("cell$(cell.id)label", text = cell.source)
    on(c, hiddencell, "dblclick") do cm::ComponentModifier
        evaluate(c, cell, cm)
    end
    style!(name, "color" => "white")
    push!(hiddencell, name)
    hiddencell
end
#==
session cells
==#
"""
**Interface**
### build(c::Connection, cm::ComponentModifier, cell::Cell{<:Any}, cells::Vector{Cell{<:Any}}, windowname::String) -> ::Component{:div}
------------------
The catchall/default `build` function for session cells. This function is what
creates the gray boxes for cells that Olive cannot create.
Using this function as a template, you can create your own olive cells.
#### example
```

```
"""
function build(c::Connection, cm::ComponentModifier, cell::Cell{<:Any},
    cells::Vector{Cell{<:Any}}, windowname::String)
    hiddencell = div("cell$(cell.id)", class = "cell-hidden")
    name = a("cell$(cell.id)label", text = cell.source)
    style!(name, "color" => "black")
    push!(hiddencell, name)
    hiddencell
end

"""
**Interface**
### evaluate(c::Connection, cell::{<:Any}, cm::ComponentModifier) -> ::Nothing
------------------
This is the catchall/default function for the evaluation of any cell. Use this
as a template to add evaluation to your cell using the `evaluate` method binding.
If you were to, say bind your cell without using evaluate, the only problem would
be it will not run with the `runall` window button.
#### example
```

```
"""
function evaluate(c::Connection, cell::Cell{<:Any}, cm::ComponentModifier,
    window::String)

end

function build_base_cell(c::Connection, cm::ComponentModifier, cell::Cell{<:Any},
    cells::Vector{Cell{<:Any}}, windowname::String)

end

function build(c::Connection, cm::ComponentModifier, cell::Cell{:creator},
    cells::Vector{Cell}, windowname::String)
    olmod = c[:OliveCore].olmod
    signatures = [m.sig.parameters[4] for m in methods(Olive.build,
    [Toolips.AbstractConnection, Toolips.Modifier, IPyCells.AbstractCell, Vector{Cell}, String])]
     buttonbox = div("cellcontainer$(cell.id)")
     push!(buttonbox, h("spawn$(cell.id)", 3, text = "new cell"))
     for sig in signatures
         if sig == Cell{:creator} || sig == Cell{<:Any}
             continue
         end
         if length(sig.parameters) < 1
             continue
         end
         b = button("$(sig)butt", text = string(sig.parameters[1]))
         on(c, b, "click") do cm2::ComponentModifier
             pos = findfirst(lcell -> lcell.id == cell.id, cells)
             remove!(cm2, buttonbox)
             new_cell = Cell(pos, string(sig.parameters[1]), "")
             deleteat!(cells, pos)
             insert!(cells, pos, new_cell)
             insert!(cm2, windowname, pos, build(c, cm2, new_cell, cells,
              windowname))
         end
         push!(buttonbox, b)
     end
     buttonbox
end

function build(c::Connection, cm::ComponentModifier, cell::Cell{:code},
    cells::Vector{Cell}, windowname::String)
    keybindings = c[:OliveCore].client_data[getip(c)]["keybindings"]
    km = ToolipsSession.KeyMap()
#==    io = IOBuffer()
    highlight(io, MIME("text/html"), cell.source, Lexers.JuliaLexer) ==#
    tm = ToolipsMarkdown.TextModifier(cell.source)
    ToolipsMarkdown.julia_block!(tm)
    outside = div("cellcontainer$(cell.id)", class = "cell")
    inside = ToolipsDefaults.textdiv("cell$(cell.id)",
    text = replace(cell.source, "\n" => "</br>"), "class" => "input_cell")
    style!(inside, "border-top-left-radius" => 0px)
    inputbox = div("cellinput$(cell.id)")
    style!(inputbox, "padding" => 0px, "width" => 90percent,
    "overflow" => "hidden", "border-top-left-radius" => "0px !important", "border-bottom-left-radius" => 0px,
    "border-radius" => "0px !important")
    highlight_box = div("cellhighlight$(cell.id)",
    text = replace(string(tm), "\n" => "</br>", "class"  => "input_cell"))
    style!(highlight_box, "position" => "absolute",
    "background" => "transparent", "z-index" => "5", "padding" => 20px,
    "border-top-left-radius" => "0px !important",
    "border-radius" => "0px !important", "line-height" => 15px,
    "max-width" => 90percent, "border-width" =>  0px,  "pointer-events" => "none",
    "color" => "#4C4646", "border-radius" => 0px, "font-size" => 13pt, "letter-spacing" => 1px,
    "font-family" => """"Lucida Console", "Courier New", monospace;""", "line-height" => 24px)
    push!(inputbox, highlight_box, inside)
    style!(outside, "transition" => 1seconds)
    on(c, cm, inside, "input", ["rawcell$(cell.id)", "cell$(cell.id)"]) do cm::ComponentModifier
        curr = cm["cell$(cell.id)"]["text"]
        currraw = cm["rawcell$(cell.id)"]["text"]
        if currraw == "]"
            pos = findall(lcell -> lcell.id == cell.id, cells)[1]
            new_cell = Cell(pos, "pkgrepl", "")
            cells[pos] = new_cell
            cell = new_cell
            remove!(cm, outside)
            ToolipsSession.insert!(cm, windowname, pos, build(c, cm, new_cell,
             cells, windowname))
            focus!(cm, "cell$(cell.id)")
        elseif currraw == ";"
            olive_notify!(cm, "bash cells not yet available!", color = "red")
        elseif currraw == "\\"
            olive_notify!(cm, "olive cells not yet available!", color = "red")
        elseif currraw == "?"
            pos = findfirst(lcell -> lcell.id == cell.id, cells)
            new_cell = Cell(pos, "helprepl", "")
            cells[pos] = new_cell
            cell = new_cell
            remove!(cm, outside)
            ToolipsSession.insert!(cm, windowname, pos, build(c, cm, new_cell,
             cells, windowname))
            focus!(cm, "cell$(cell.id)")
        elseif currraw == "#=TODO"
            pos = findfirst(lcell -> lcell.id == cell.id, cells)
            new_cell = Cell(pos, "TODO", "")
            remove!(cm, outside)
            ToolipsSession.insert!(cm, windowname, pos, build(c, cm, new_cell,
             cells, windowname))
            focus!(cm, "cell$(cell.id)")
        end
        #f = findprev("\n", curr)
        #==TODO  we need to findlast, remove whatever the control key is from the last
         space... In other words, we need to scan for the evaluate controls
        So in the example  of it being enter, we need to find the last \n,
        which is just html </br> replaced by ToolipsSession (cm[comp]["text"]
        is preprocessed.)
        ==#
        cell.source = curr
        tm = TextModifier(replace(curr, "\n" => "<br>", " " => "&nbsp;"))

        ToolipsMarkdown.julia_block!(tm)
        set_text!(cm, highlight_box, string(tm))
    end
    interiorbox = div("cellinterior$(cell.id)")
    style!(interiorbox, "display" => "flex")
    sidebox = div("cellside$(cell.id)")
    style!(sidebox, "display" => "inline-block", "background-color" => "pink",
    "border-bottom-right-radius" => 0px, "border-top-right-radius" => 0px,
    "overflow" => "hidden", "border-style" => "solid", "border-width" => 1px)
    push!(interiorbox, sidebox, inputbox)
    cell_drag = topbar_icon("cell$(cell.id)drag", "drag_indicator")
    cell_run = topbar_icon("cell$(cell.id)drag", "play_arrow")
    push!(sidebox, cell_drag, br(), cell_run)
    style!(cell_drag, "color" => "white", "font-size" => 17pt)
    style!(cell_run, "color" => "white", "font-size" => 17pt)
    output = divider("cell$(cell.id)out", class = "output_cell", text = cell.outputs)
    push!(outside, interiorbox, output)
    on(c, cell_run, "click") do cm2::ComponentModifier
            evaluate(c, cell, cm2)
    end
    bind!(km, keybindings[:evaluate] ...) do cm2::ComponentModifier
        icon = olive_loadicon()
        icon.name = "load$(cell.id)"
        icon["width"] = "20"
        remove!(cm2, cell_run)
        currcaret = parse(Int64, cm2["cell$(cell.id)"]["caret"]) + 1
        newtxt = cm2["cell$(cell.id)"]["text"]
        newtxt = newtxt[1:currcaret - 1] * newtxt[currcaret:length(newtxt)]
        set_text!(cm2, "cell$(cell.id)", replace(newtxt, "\n" => "</br>", " " => "&nbsp;"))
        set_children!(cm2, "cellside$(cell.id)", [icon])
        script!(c, cm2, "$(cell.id)eval") do cm3::ComponentModifier
            evaluate(c, cell, cm3, windowname)
            pos = findall(lcell -> lcell.id == cell.id, cells)[1]
            pos = findall(lcell -> lcell.id == cell.id, cells)[1]
            if pos == length(cells)
                new_cell = Cell(length(cells) + 1, "code", "", id = ToolipsSession.gen_ref())
                push!(cells, new_cell)
                append!(cm3, windowname, build(c, cm3, new_cell, cells, windowname))
                focus!(cm3, "cell$(new_cell.id)")
                set_children!(cm3, sidebox, [cell_drag, br(), cell_run])
                return
            end
            next_cell = cells[pos + 1]
            focus!(cm3, "cell$(next_cell.id)")
            set_children!(cm3, sidebox, [cell_drag, br(), cell_run])
        end
    end
    bind!(km, keybindings[:up] ...) do cm2::ComponentModifier
        cell_up!(c, cm2, cell, cells, windowname)
    end
    bind!(km, keybindings[:down] ...) do cm2::ComponentModifier
        cell_down!(c, cm2, cell, cells, windowname)
    end
    bind!(km, keybindings[:delete] ...) do cm2::ComponentModifier
        cell_delete!(c, cm2, cell, cells)
    end
    bind!(km, keybindings[:new] ...) do cm2::ComponentModifier
        cell_new!(c, cm2, cell, cells, windowname)
    end
    bind!(c, cm, inside, km)
    outside
end

function evaluate(c::Connection, cell::Cell{:code}, cm::ComponentModifier,
    window::String)
    # get code
    rawcode::String = cm["cell$(cell.id)"]["text"]
    execcode::String = *("begin\n", rawcode, "\nend\n")
    # get project
    selected::String = cm["olivemain"]["selected"]
    proj::Project{<:Any} = c[:OliveCore].open[getip(c)]
    ret::Any = ""
    p = Pipe()
    err = Pipe()
   redirect_stdio(stdout = p, stderr = err) do
        try
            ret = proj.open[window][:mod].evalin(Meta.parse(execcode))
        catch e
            ret = e
        end
    end
    close(err)
    close(Base.pipe_writer(p))
    standard_out = read(p, String)
    close(p)
    # output
    outp::String = ""
    od = OliveDisplay()
    if typeof(ret) <: Exception
        Base.showerror(od.io, ret)
        outp = replace(String(od.io.data), "\n" => "</br>")
    elseif ~(isnothing(ret)) && length(standard_out) > 0
        display(od, MIME"olive"(), ret)
        outp = standard_out * "</br>" * String(od.io.data)
    elseif ~(isnothing(ret)) && length(standard_out) == 0
        display(od, MIME"olive"(), ret)
        outp = String(od.io.data)

    else
        outp = standard_out
    end
    set_text!(cm, "cell$(cell.id)out", outp)
    cell.outputs = outp
end

function build(c::Connection, cm::ComponentModifier, cell::Cell{:markdown},
    cells::Vector{Cell}, windowname::String)
    keybindings = c[:OliveCore].client_data[getip(c)]["keybindings"]
    km = ToolipsSession.KeyMap()
    tlcell = ToolipsDefaults.textdiv("cell$(cell.id)",
    "class" => "cell")
    tlcell[:text] = ""
    tlcell[:contenteditable] = false
    conta = div("cellcontainer$(cell.id)")
    style!(tlcell, "border-width" => 2px, "border-style" => "solid",
    "min-height" => 2percent)
    innercell = tmd("celltmd$(cell.id)", cell.source)
    style!(innercell, "min-hight" => 2percent)
    on(c, cm, tlcell, "dblclick") do cm::ComponentModifier
        set_text!(cm, tlcell, replace(cell.source, "\n" => "</br>"))
        cm["olivemain"] = "cell" => string(cell.n)
        cm[tlcell] = "contenteditable" => "true"
    end
    bind!(km, keybindings[:evaluate] ...) do cm2::ComponentModifier
        cell.source = cm2[tlcell]["text"]
        evaluate(c, cell, cm2, windowname)
    end
    bind!(km, keybindings[:up] ...) do cm2::ComponentModifier
        cell_up!(c, cm2, cell, cells, windowname)
    end
    bind!(km, keybindings[:down] ...) do cm2::ComponentModifier
        cell_down!(c, cm2, cell, cells, windowname)
    end
    bind!(km, keybindings[:delete] ...) do cm2::ComponentModifier
        cell_delete!(c, cm2, cell, cells)
    end
    bind!(km, keybindings[:new] ...) do cm2::ComponentModifier
        cell_new!(c, cm2, cell, cells, windowname, type = "markdown")
    end
    bind!(c, cm, tlcell, km)
    tlcell[:children] = [innercell]
    push!(conta, tlcell)
    conta
end

function build(c::Connection, cm::ComponentModifier, cell::Cell{:helprepl},
    cells::Vector{Cell}, windowname::String)
    km = bind!(c, cell, cells, windowname)
    src = ""
    if contains(cell.source, "#")
        src = split(cell.source, "?")[2]
    end
    cell.source = src
    outside = div("cellcontainer$(cell.id)", class = "cell")
    inner  = div("cellinside$(cell.id)")
    style!(inner, "display" => "flex")
    inside = ToolipsDefaults.textdiv("cell$(cell.id)", text = cell.source)
    bind!(km, "Backspace") do cm2::ComponentModifier
        if cm2["rawcell$(cell.id)"]["text"] == ""
            pos = findfirst(lcell -> lcell.id == cell.id, cells)
            new_cell = Cell(pos, "code", "")
            cells[pos] = new_cell
            cell = new_cell
            remove!(cm2, outside)
            built = build(c, cm2, new_cell, cells, windowname)
            ToolipsSession.insert!(cm2, windowname, pos, built)
            focus!(cm2, "cell$(cell.id)")
        end
    end
    sidebox = div("cellside$(cell.id)")
    style!(sidebox, "display" => "inline-block",
    "background-color" => "orange",
    "border-bottom-right-radius" => 0px, "border-top-right-radius" => 0px,
    "overflow" => "hidden", "border-style" => "solid",
    "border-width" => 2px)
    pkglabel =  a("$(cell.id)helplabel", text = "help>")
    style!(pkglabel, "font-weight" => "bold", "color" => "black")
    push!(sidebox, pkglabel)
    style!(inside, "width" => 80percent, "border-bottom-left-radius" => 0px,
    "border-top-left-radius" => 0px,
    "min-height" => 50px, "display" => "inline-block",
     "margin-top" => 0px, "font-weight" => "bold",
     "background-color" => "#b33000", "color" => "white", "border-style" => "solid",
     "border-width" => 2px)
     output = div("cell$(cell.id)out", text = cell.outputs)
     push!(inner, sidebox, inside)
    push!(outside, inner, output)
    bind!(c, cm, inside, km)
    outside
end

function build(c::Connection, cm::ComponentModifier, cell::Cell{:tomlcategory},
    cells::Vector{Cell})
   catheading = h("cell$(cell.id)heading", 2, text = cell.source, contenteditable = true)
    contents = section("cell$(cell.id)")
    push!(contents, catheading)
    v = string(cell.outputs)
    equals = a("equals", text = " = ")
    style!(equals, "color" => "gray")
    for (k, v) in cell.outputs
        key_div = div("keydiv")
        push!(key_div,
        a("$(cell.n)$k", text = string(k), contenteditable = true), equals,
        a("$(cell.n)$k$v", text = string(v), contenteditable = true))
        push!(contents, key_div)
    end
    contents
end

function build(c::Connection, cm::ComponentModifier, cell::Cell{:tomlval},
    cells::Vector{Cell})
        key_div = div("cell$(cell.id)")
        k = cell.source
        v = string(cell.outputs)
        equals = a("equals", text = " = ")
        style!(equals, "color" => "gray")
        push!(key_div,
        a("$(cell.n)$k", text = string(k), contenteditable = true), equals,
        a("$(cell.n)$k$v", text = string(v), contenteditable = true))
        key_div
end

function build(c::Connection, cm::ComponentModifier, cell::Cell{:pkgrepl},
    cells::Vector{Cell}, windowname::String)
    cell.source = ""
    keybindings = c[:OliveCore].client_data[getip(c)]["keybindings"]
    km = ToolipsSession.KeyMap()
    outside = div("cellcontainer$(cell.id)", class = "cell")
    output = div("cell$(cell.id)out")
    style!(outside, "display" => "flex")
    inside = ToolipsDefaults.textdiv("cell$(cell.id)", text = "")
    bind!(km, "Backspace") do cm2::ComponentModifier
        if cm2["rawcell$(cell.id)"]["text"] == ""
            pos = findfirst(lcell -> lcell.id == cell.id, cells)
            new_cell = Cell(pos, "code", "")
            cells[pos] = new_cell
            cell = new_cell
            remove!(cm2, outside)
            built = build(c, cm2, new_cell, cells, windowname)
            ToolipsSession.insert!(cm2, windowname, pos, built)
            focus!(cm2, "cell$(cell.id)")
        end
    end
    bind!(km, keybindings[:evaluate] ...) do cm2::ComponentModifier
        mod = c[:OliveCore].open[getip(c)].open[windowname][:mod]
        rt = cm2["rawcell$(cell.id)"]["text"]
        commandarg = split(rt, " ")
        if length(commandarg) == 2
            evalstr = "Pkg.$(commandarg[1])(\"$(commandarg[2])\""
            if contains(commandarg[2], "http")
                evalstr = "Pkg.$(commandarg[1])(url = \"$(commandarg[2])\""
            end
            if contains(commandarg[2], "#")
                l = length(commandarg[2])
                revision = commandarg[2][findfirst("#", commandarg[2])[1] + 1:l]
                evalstr = evalstr * ", rev = \"$(revision)\""
            end
            if contains(commandarg[2], "@")
                l = length(commandarg[2])
                version = commandarg[2][findfirst("@", commandarg[2])[1] + 1:l]
                evalstr = evalstr * ", version = \"$(version)\""
            end
            evalstr = evalstr * ")"
            mod.evalin(Meta.parse(evalstr))
            cell.source = cell.source * "\n" * evalstr
            cell.outputs = cell.outputs * "\n" * evalstr
            set_text!(cm2, output, cell.outputs)
        else
            olive_notify!(cm2, "Pkg: invalid usage '$(commandarg[1])'", color = "blue")
        end
    end
    bind!(km, keybindings[:up] ...) do cm2::ComponentModifier
        cell_up!(c, cm2, cell, cells, windowname)
    end
    bind!(km, keybindings[:down] ...) do cm2::ComponentModifier
        cell_down!(c, cm2, cell, cells, windowname)
    end
    bind!(km, keybindings[:delete] ...) do cm2::ComponentModifier
        cell_delete!(c, cm2, cell, cells)
    end
    bind!(km, keybindings[:new] ...) do cm2::ComponentModifier
        cell_new!(c, cm2, cell, cells, windowname)
    end
    sidebox = div("cellside$(cell.id)")
    style!(sidebox, "display" => "inline-block",
    "background-color" => "blue",
    "border-bottom-right-radius" => 0px, "border-top-right-radius" => 0px,
    "overflow" => "hidden", "border-width" => 2px, "border-style" => "solid")
    pkglabel =  a("$(cell.id)pkglabel", text = "pkg>")
    style!(pkglabel, "font-weight" => "bold", "color" => "white")
    push!(sidebox, pkglabel)
    style!(inside, "width" => 80percent, "border-bottom-left-radius" => 0px,
    "border-top-left-radius" => 0px,
    "min-height" => 50px, "display" => "inline-block",
     "margin-top" => 0px, "font-weight" => "bold",
     "background-color" => "#301934", "color" => "white", "border-width" => 2px,
     "border-style" => "solid")
    push!(outside, sidebox, inside, output)
    bind!(c, cm, inside, km, ["cell$(cell.id)"])
    outside
end

"""
**Interface**
### evaluate(c::Connection, cell::{<:Any}, cm::ComponentModifier) -> ::Nothing
------------------
This is the catchall/default function for the evaluation of any cell.
#### example
```

```
"""
function evaluate(c::Connection, cell::Cell{:pkgrepl}, cm::ComponentModifier,
    window::String)

end

function build(c::Connection, cm::ComponentModifier, cell::Cell{:shell},
    cells::Vector{Cell})
    keybindings = c[:OliveCore].client_data[getip(c)]["keybindings"]

end

function build(c::Connection, cell::Cell{:setup})
    maincell = section("cell$(cell.id)", align = "center")
    push!(maincell, olive_cover())
    push!(maincell, h("setupheading", 1, text = "welcome !"))
    push!(maincell, p("setuptext", text = """Olive requires a home directory
    in order to store your configuration, please select a home directory
    in the cell below. Olive will create a `/olive` directory in the chosen
    directory."""))
    maincell
end

function build_returner(c::Connection, path::String)
    returner_div = div("returner")
    style!(returner_div, "background-color" => "red", "cursor" => "pointer")
    push!(returner_div, a("returnerbutt", text = "..."))
    on(c, returner_div, "click") do cm::ComponentModifier
        paths = split(path, "/")
        path = join(paths[1:length(paths) - 1], "/")
        set_text!(cm, "selector", path)
        set_children!(cm, "filebox", Vector{Servable}(vcat(
        build_returner(c, path),
        [build_comp(c, path, f) for f in readdir(path)]))::Vector{Servable})
    end
    returner_div
end

function build_comp(c::Connection, path::String, dir::String)
    if isdir(path * "/" * dir)
        maincomp = div("$dir")
        style!(maincomp, "background-color" => "lightblue", "cursor" => "pointer")
        push!(maincomp, a("$dir-a", text = dir))
        on(c, maincomp, "click") do cm::ComponentModifier
            path = path * "/" * dir
            set_text!(cm, "selector", path)
            children = Vector{Servable}([build_comp(c, path, f) for f in readdir(path)])::Vector{Servable}
            set_children!(cm, "filebox", vcat(Vector{Servable}([build_returner(c, path)]), children))
        end
        return(maincomp)::Component{:div}
    end
    maincomp = div("$dir")
    push!(maincomp, a("$dir-a", text = dir))
    maincomp::Component{:div}
end

function build(c::Connection, cell::Cell{:dirselect})
    selector_indicator = h("selector", 4, text = cell.source)
    path = cell.source
    filebox = section("filebox")
    style!(filebox, "height" => 40percent, "overflow-y" => "scroll")
    filebox[:children] = vcat(Vector{Servable}([build_returner(c, path)]),
    Vector{Servable}([build_comp(c, path, f) for f in readdir(path)]))
    cellover = div("dirselectover")
    push!(cellover, selector_indicator, filebox)
    cellover
end

function evaluate(c::Connection, cell::Cell{<:Any}, cm::ComponentModifier)

end

function evaluate(c::Connection, cell::Cell{:toml}, cm::ComponentModifier)
    toml_cats = TOML.parse(read(cell.outputs, String))
    cs::Vector{Cell{<:Any}} = [begin if typeof(keycategory[2]) <: AbstractDict
        Cell(e, "tomlcategory", keycategory[1], keycategory[2], id = ToolipsSession.gen_ref())
    else
        Cell(e, "tomlval", keycategory[1], keycategory[2], id = ToolipsSession.gen_ref())
    end
    end for (e, keycategory) in enumerate(toml_cats)]
    Olive.load_session(c, cs, cm, cell.source, cell.outputs)
end

function evaluate(c::Connection, cell::Cell{:markdown}, cm::ComponentModifier,
    window::String)
    if cm["cell$(cell.id)"]["contenteditable"] == "true"
        activemd = cm["cell$(cell.id)"]["text"]
        cell.source = activemd * "\n"
        newtmd = tmd("cell$(cell.id)tmd", cell.source)
        set_children!(cm, "cell$(cell.id)", [newtmd])
        cm["cell$(cell.id)"] = "contenteditable" => "false"
    end
end

function evaluate(c::Connection, cell::Cell{:ipynb}, cm::ComponentModifier)
    cs::Vector{Cell{<:Any}} = IPyCells.read_ipynb(cell.outputs)
    load_session(c, cs, cm, cell.source, cell.outputs)
end

function directory_cells(dir::String = pwd(), access::Pair{String, String} ...)
    files = readdir(dir)
    return([build_file_cell(e, path, dir) for (e, path) in enumerate(files)]::AbstractVector)
end

function build_file_cell(e::Int64, path::String, dir::String)
    if ~(isdir(dir * "/" * path))
        splitdir::Vector{SubString} = split(path, "/")
        fname::String = string(splitdir[length(splitdir)])
        fsplit = split(fname, ".")
        fending::String = ""
        if length(fsplit) > 1
            fending = string(fsplit[2])
        end
        Cell(e, fending, fname, dir * "/" * path)
    else
        Cell(e, "dir", path, dir)
    end
end
