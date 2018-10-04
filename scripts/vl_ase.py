#!/usr/bin/python
#****************************************************************************
#* vl_ase.py
#*
#* Processes a Verilator DPI header and additional information to 
#* create a DPI interface
#*
#* - hdl_hvl_api.h
#*   - Declares the API structures used to communicate
#* - hdl_dpi.cpp
#* - hvl_dpi.c
#****************************************************************************
import os.path
import sys
import subprocess
import re

class dpi_type:
  def __init__(self, typename):
    self.typename = typename

  def tostr(self):
    ret = ""
    for i in range(len(self.typename)):
      ret += self.typename[i]
      if i+1 < len(self.typename):
        ret += " "
    return ret

  def is_void(self):
    if len(self.typename) == 1 and self.typename[0] == "void":
      return True
    else:
      return False

class dpi_param:
  def __init__(self, typename, name):
    self.typename = typename
    self.name = name
    self.dpi_funcs = []


class dpi_func:
  def __init__(self, name, is_export, returntype, params):
    self.name = name
    self.is_export = is_export
    self.returntype = returntype
    self.params = params;

  def get_name(self, is_hvl):
    name = self.name

    if is_hvl:
      name = name[:-4] + "_hvl";

    return name;

  def prototype(self, is_hvl, prefix="", force_int_ret=False):
    proto = ""

    name = self.name

    if is_hvl:
      name = name[:-4] + "_hvl";

    if self.is_export and force_int_ret:
      proto += "int "
    else: 
      proto += self.returntype.tostr() + " "

    proto += prefix + name + "("
    for i in range(len(self.params)):
      proto += self.params[i].typename.tostr() + " "
      proto += self.params[i].name
      if i+1 < len(self.params):
        proto += ", "
    proto += ")"
    return proto

  def ptr_prototype(self, is_hvl, prefix=""):
    proto = ""

    proto += self.returntype.tostr() + " "

    name = self.name

    if is_hvl:
      name = name[:-4] + "_hvl";

    proto += "(*" + prefix + name + ")("
    for i in range(len(self.params)):
      proto += self.params[i].typename.tostr() + " "
      proto += self.params[i].name
      if i+1 < len(self.params):
        proto += ", "
    proto += ")"
    return proto

  def ptr_type(self):
    proto = ""

    proto += self.returntype.tostr() + " "

    proto += "(*)("
    for i in range(len(self.params)):
      proto += self.params[i].typename.tostr()
      if i+1 < len(self.params):
        proto += ", "
    proto += ")"
    return proto
  
  def call(self, is_hvl, prefix=""):
    name = self.name

    if is_hvl:
      name = name[:-4] + "_hvl";

    str = name + "("
    for i in range(len(self.params)):
      str += self.params[i].name
      if i+1 < len(self.params):
        str += ", "

    str += ")"
  
    return str 

  def is_void(self):
    return self.returntype.is_void()

class bfm:
  def __init__(self, bfm_name):
    self.bfm_name = bfm_name
    self.dpi_funcs = []

class tokenstream:
  def __init__(self, line):
    elems = line.split()
    self.elems = []
    for elem in elems:
      if elem.startswith("("):
        self.elems.append("(")
        self.elems.append(elem[1:])
      elif elem.endswith(");"):
        self.elems.append(elem[:-2])
        self.elems.append(")")
      elif elem.endswith(","):
        self.elems.append(elem[:-1])
        self.elems.append(",")
      elif elem.startswith("*"):
        self.elems.append("*")
        self.elems.append(elem[1:])
      elif elem.endswith("*"):
        self.elems.append(elem[:-1])
        self.elems.append("*")
      elif elem != "extern":
        self.elems.append(elem);
    self.idx = 0

  def next(self):
    if self.idx < len(self.elems):
      idx = self.idx;
      self.idx = self.idx+1
      return self.elems[idx]
    else:
      return None;

  def peek(self):
    if self.idx < len(self.elems):
      return self.elems[self.idx]
    else:
      return None;


class vl_ase:
  def __init__(self, obj_dir, top):
    self.obj_dir = obj_dir
    self.top = top
    self.clocks = []
    self.bfms = []
    self.dpi_funcs = []

  #******************************************************************
  #* Read the Verilator DPI header and extract DPI imports and 
  #* exports
  #******************************************************************
  def read_dpi(self):
    fh = open(self.obj_dir + "/V" + self.top + "__Dpi.h", "r");
    imp_exp = re.compile("// DPI import")

    while True:
      l = fh.readline()
      if l != "":
        l = l.strip()
        if l.startswith("// DPI import"):
          l = fh.readline()
#          print "Import: " + l
          self.dpi_funcs.append(self.process_function(False, tokenstream(l)))
        elif l.startswith("// DPI export"):
          l = fh.readline()
#          print "Export: " + l
          self.dpi_funcs.append(self.process_function(True, tokenstream(l)))
      else:
        break

    fh.close()


#    self.find_bfms(dpi_funcs)


  #******************************************************************
  #* generate()
  #* Generates the output files
  #******************************************************************
  def generate(self):
    self.generate_hvl_hdl_api_h()
    self.generate_hvl_dpi_c()
    self.generate_hdl_dpi_c()
    self.generate_top_vl_ase()
   
 
  #******************************************************************
  #* generate_hdl_hvl_api_h()
  #* Generates the API header file
  #******************************************************************
  def generate_hvl_hdl_api_h(self):
    fh = open(self.obj_dir + "/hdl_hvl_api.h", "w")

    fh.write("#ifndef INCLUDED_HVL_HDL_API_H\n")
    fh.write("#define INCLUDED_HVL_HDL_API_H\n")
    fh.write("// API called from the HVL side\n")
    fh.write("typedef struct hvl_hdl_api_s {\n")
    fh.write("  void (*eval)(void); // evaluation function\n")
    fh.write("  void (*close)(void); // shutdown function\n")
    for bfm in self.bfms:
      for dpi in bfm.dpi_funcs:
        # The HVL side will access functions marked EXPORT
        if dpi.is_export:
          fh.write("  " + dpi.ptr_prototype(False) + ";\n")
    fh.write("} hvl_hdl_api_t;\n")
    fh.write("// API called from the HDL side\n")
    fh.write("typedef struct hdl_hvl_api_s {\n")
    for bfm in self.bfms:
      for dpi in bfm.dpi_funcs:
        # The HDL side will access functions marked IMPORT
        if dpi.is_export == False:
          fh.write("  " + dpi.ptr_prototype(True) + ";\n")

    # Each BFM requires some boilerplate, as well as its DPI functions
    fh.write("} hdl_hvl_api_t;\n")
    fh.write("#endif /* INCLUDED_HVL_HDL_API_H */\n")

    fh.close()

  #******************************************************************
  #* generate_hvl_dpi_c()
  #* Generates DPI imported by the HVL side
  #******************************************************************
  def generate_hvl_dpi_c(self):
    fh = open(self.obj_dir + "/hvl_dpi.c", "w");
    fh.write("#include \"hdl_hvl_api.h\"\n")
    fh.write("#include <stdint.h>\n")
    fh.write("#include <dlfcn.h>\n")
    fh.write("#include <stdio.h>\n")
    fh.write("#include <unistd.h>\n")
    fh.write("#include <string.h>\n")
    fh.write("#include <stdio.h>\n")
    fh.write("#include \"vpi_user.h\"\n")
    fh.write("\n")
    fh.write("const void *svGetScope(void);\n")
    fh.write("void svSetScope(const void *);\n")
    fh.write("\n")
    fh.write("// Handle to the HDL API to be called from the HVL\n")
    fh.write("static hvl_hdl_api_t *hvl_hdl_api = 0;\n")

    # Implement the HVL-side API for each BFM
    for bfm_i in self.bfms:
      fh.write("//******************************************************************\n")
      fh.write("//* BFM: " + bfm_i.bfm_name + "\n")
      fh.write("//******************************************************************\n")
      fh.write("static const void *prv_" + bfm_i.bfm_name + "_pkg_scope = 0;\n")
      fh.write("\n")
      fh.write("void " + bfm_i.bfm_name + "_pkg_init(void) {\n")
      fh.write("  prv_" + bfm_i.bfm_name + "_pkg_scope = svGetScope();\n")
      fh.write("  fprintf(stdout, \"" + bfm_i.bfm_name + "_pkg_init:\\n\");\n")
      fh.write("  fflush(stdout);\n");
      fh.write("}\n")
      fh.write("\n")

      for dpi in bfm_i.dpi_funcs:
        #* DPI-export functions require a wrapper function on the HVL side 
        #* that will set the correct package scope before calling
        if dpi.is_export:
          fh.write(dpi.prototype(True, "", True) + " {\n")
          if dpi.is_void == False:
            fh.write("  return hvl_hdl_api->" + dpi.call(False) + ";\n")
          else:
            fh.write("  hvl_hdl_api->" + dpi.call(False) + ";\n")
            fh.write("  return 0;\n")
          fh.write("}\n")
        else:
          # Methods marked 'import' on the HDL side will have
          # an export to call here
#          fh.write("static " + dpi.ptr_prototype(True, "prv_") + " = 0;\n")
          fh.write(dpi.prototype(True) + ";\n")
          fh.write("static " + dpi.prototype(True, "_") + " {\n")
          fh.write("  fprintf(stdout, \"_" + dpi.name + ": scope=%p\\n\", prv_" + bfm_i.bfm_name + "_pkg_scope);\n")
          fh.write("  fflush(stdout);\n")
          fh.write("  svSetScope(prv_" + bfm_i.bfm_name + "_pkg_scope);\n")
          if dpi.is_void() == True:
            fh.write("  " + dpi.call(True) + ";\n")
          else:
            fh.write("  return " + dpi.call(True) + ";\n")
          fh.write("}\n")
          

    # Implement the HVL-side API
    fh.write("// HVL API to be called from the HDL\n")
    fh.write("static hdl_hvl_api_t hdl_hvl_api = {\n")

    # Register the wrapper functions that will be called
    # from the HDL side (imports)
    for bfm_i in self.bfms:
      for dpi in bfm_i.dpi_funcs:
        if dpi.is_export == False:
          fh.write("  &_" + dpi.get_name(True) + ",\n")
    fh.write("};\n")

    fh.write("\n")
    fh.write("// HVL-side initialization\n")
    fh.write("int32_t vl_ase_init(const char *obj_dir) {\n")
    fh.write("  void *hdl_lib;\n")
    fh.write("  void *exp_lib;\n")
    fh.write("  FILE *file;\n")
    fh.write("  uint32_t argc = 0;\n")
    fh.write("  char **argv = 0;\n")
    fh.write("  char *export_tramp = 0;\n")
    fh.write("  char path[512];\n")
    fh.write("  s_vpi_vlog_info vlog_info;\n")
    fh.write("\n")
    fh.write("  vpi_get_vlog_info(&vlog_info);\n")
#    fh.write("  sprintf(path, \"/proc/%d/maps\", getpid());\n")
#    fh.write("  file = fopen(path, \"r\");\n")
#    fh.write("  while (fgets(path, sizeof(path), file)) {\n")
#    fh.write("    if (strstr(path, \"vsim_auto_compile\")) {\n")
#    fh.write("      export_tramp = strchr(path, '/');\n")
#    fh.write("      export_tramp[strlen(export_tramp)-1] = 0;\n")
#    fh.write("    }\n")
#    fh.write("  }\n")
#    fh.write("\n")
#    fh.write("  exp_lib = dlopen(export_tramp, RTLD_LAZY);\n")
    fh.write("\n")
    fh.write("  sprintf(path, \"%s/V" + self.top + "\", obj_dir);\n")
    fh.write("  hvl_hdl_api_t *(*vl_ase_hdl_init)(void *, hdl_hvl_api_t *, uint32_t, char **);\n")
    fh.write("  if (!(hdl_lib = dlopen(path, RTLD_LAZY))) {\n")
    fh.write("    fprintf(stdout, \"Fatal: failed to load %s: %s\\n\", path, dlerror());\n")
    fh.write("    fflush(stdout);\n")
    fh.write("    return -1;\n")
    fh.write("  }\n")
    fh.write("\n")
    fh.write("  vl_ase_hdl_init = (hvl_hdl_api_t *(*)(void *, hdl_hvl_api_t *, uint32_t, char **))dlsym(hdl_lib, \"vl_ase_hdl_init\");\n")
    fh.write("  if (!vl_ase_hdl_init) {\n")
    fh.write("    fprintf(stdout, \"Fatal: failed to find symbol vl_ase_hdl_init: %s\\n\", dlerror());\n")
    fh.write("    fflush(stdout);\n")
    fh.write("    return -1;\n")
    fh.write("  }\n")


#    for bfm_i in self.bfms:
#      for dpi in bfm_i.dpi_funcs:
#        if dpi.is_export == False:
#          fh.write("  prv_" + dpi.name + " = (" + dpi.ptr_type() + ")dlsym(exp_lib, \"" + dpi.name + "\");\n")
#          fh.write("  if (!prv_" + dpi.name + ") {\n")
#          fh.write("    fprintf(stdout, \"Fatal: failed to find symbol " + dpi.name + ": %s\\n\", dlerror());\n")
#          fh.write("    fflush(stdout);\n")
#          fh.write("    return -1;\n")
#          fh.write("  }\n")
    fh.write("\n")
    fh.write("  hvl_hdl_api = vl_ase_hdl_init(hdl_lib, &hdl_hvl_api, vlog_info.argc, vlog_info.argv);\n")
    fh.write("\n")
    fh.write("  return 0;\n")
    fh.write("}\n")
    fh.write("\n")
    fh.write("void vl_ase_eval(void) {\n")
    fh.write("  hvl_hdl_api->eval();\n")
    fh.write("}\n")
    fh.write("// HVL-side shutdown\n")
    fh.write("void vl_ase_close(void) {\n")
    fh.write("  fprintf(stdout, \"vl_ase_close()\\n\");\n")
    fh.write("  if (hvl_hdl_api) {\n")
    fh.write("    hvl_hdl_api->close();\n")
    fh.write("  } else {\n")
    fh.write("    fprintf(stdout, \"hvl_hdl_api is null\\n\");\n")
    fh.write("  }\n")
    fh.write("}\n")
    fh.write("\n")
    fh.close()
  
  #******************************************************************
  #* generate_hdl_dpi_c()
  #* Generates DPI imported by the HDL side
  #******************************************************************
  def generate_hdl_dpi_c(self):
    fh = open(self.obj_dir + "/hdl_dpi.cpp", "w");
    fh.write("#include \"hdl_hvl_api.h\"\n")
    fh.write("#include \"V" + self.top + ".h\"\n")
    fh.write("#include \"V" + self.top + "__Dpi.h\"\n")
    fh.write("#include <stdint.h>\n")
    fh.write("#include <map>\n")
    fh.write("#include <dlfcn.h>\n")
    fh.write("#include \"verilated.h\"\n")
    fh.write("#include \"verilated_lxt2_c.h\"");
    fh.write("\n")
    fh.write("// Handle to the HVL API to be called from the HDL\n")
    fh.write("static hdl_hvl_api_t *hdl_hvl_api = 0;\n")

    # Register the wrapper functions that will be called
    for bfm_i in self.bfms:
      bfm_name = bfm_i.bfm_name

      fh.write("//******************************************************************\n")
      fh.write("//* BFM: " + bfm_name + "\n")
      fh.write("//******************************************************************\n")

      # Each BFM requires an Id/Scope map 
      fh.write("static std::map<uint32_t, const VerilatedScope *>    prv_" + bfm_name + "_id_scope_map;\n")
      for dpi in bfm_i.dpi_funcs:
        if dpi.name.endswith("_register_hdl"):
          fh.write("extern \"C\" " + dpi.prototype(False) + " {\n")
          fh.write("  uint32_t id = hdl_hvl_api->" + dpi.call(True) + ";\n")
          fh.write("  prv_" + bfm_name + "_id_scope_map[id] = Verilated::dpiScope();\n")
          fh.write("  return id;\n")
          fh.write("}\n")
        elif dpi.is_export:
          # An export is provided by the simulator. We must implement
          # a call to that function in such a way that we don't accidentally
          # call the import function provided on the HVL side
#          fh.write("static " + dpi.ptr_prototype("prv_") + ";\n")
          fh.write("static " + dpi.prototype(False, "_") + " {\n");
          fh.write("  fprintf(stdout, \"--> " + dpi.name + "\\n\");\n")
          fh.write("  Verilated::dpiScope(prv_" + bfm_name + "_id_scope_map.find(id)->second);\n")
          if dpi.is_void:
            fh.write("  " + dpi.call(False) + ";\n")
          else:
            fh.write("  return " + dpi.call(False) + ";\n")
          fh.write("  fprintf(stdout, \"<-- " + dpi.name + "\\n\");\n")
          fh.write("}\n")
        else:
          # This is a DPI import. Must call the corresponding HVL function
          fh.write("extern \"C\" " + dpi.prototype(False) + " {\n")
          if dpi.is_void():
            fh.write("  hdl_hvl_api->" + dpi.call(True) + ";\n")
          else:
            fh.write("  return hdl_hvl_api->" + dpi.call(True) + ";\n")
          fh.write("}\n")

    fh.write("\n")
    fh.write("static V" + self.top + " *top = 0;\n")
    fh.write("static VerilatedLxt2C *tfp = 0;\n")
    fh.write("static uint64_t        timestamp = 0;\n")
    fh.write("\n")

    # Implement the evaluation function
    fh.write("static void vl_ase_hdl_eval(void) {\n")
    fh.write("  top->clk = 1;\n");
    fh.write("  top->eval();\n")
    fh.write("  timestamp += 5;\n")
    fh.write("  if (tfp) {\n")
#    fh.write("    fprintf(stdout, \"dump(): %d\\n\", (int)timestamp);\n")
    fh.write("    tfp->dump(timestamp);\n")
    fh.write("  }\n")
    fh.write("  top->clk = 0;\n");
    fh.write("  top->eval();\n")
    fh.write("  timestamp += 5;\n")
    fh.write("  if (tfp) {\n")
#    fh.write("    fprintf(stdout, \"dump(): %d\\n\", (int)timestamp);\n")
    fh.write("    tfp->dump(timestamp);\n")
    fh.write("  }\n")
    fh.write("}\n")
    fh.write("\n")
    fh.write("static void vl_ase_hdl_close(void) {\n")
    fh.write("  fprintf(stdout, \"vl_ase_hdl_close() %p\\n\", tfp);\n")
    fh.write("  if (tfp) {\n")
    fh.write("    tfp->close();\n")
    fh.write("    tfp = 0;\n");
    fh.write("  }\n")
    fh.write("}\n")
    fh.write("\n")
    fh.write("static void vl_ase_hdl_atexit(void) {\n")
    fh.write("  fprintf(stdout, \"--> vl_ase_hdl_atexit\\n\");\n")
    fh.write("  vl_ase_hdl_close();\n")
    fh.write("  fprintf(stdout, \"<-- vl_ase_hdl_atexit\\n\");\n")
    fh.write("}\n")
    fh.write("\n")

    # Register the wrapper functions that will be called
    # from the HVL side (exports)
    fh.write("// HDL API to be called from the HVL\n")
    fh.write("static hvl_hdl_api_t hvl_hdl_api = {\n")
    fh.write("  &vl_ase_hdl_eval,\n")
    fh.write("  &vl_ase_hdl_close,\n")
    for bfm_i in self.bfms:
      fh.write("  // Functions for BFM: " + bfm_i.bfm_name + "\n")
      for dpi in bfm_i.dpi_funcs:
        if dpi.is_export:
          fh.write("  &_" + dpi.name + ",\n")
    fh.write("};\n")

    fh.write("\n")

    # Implement the vl_ase_init() method
    fh.write("extern \"C\" hvl_hdl_api_t *vl_ase_hdl_init(void *lib, hdl_hvl_api_t *api, uint32_t argc, char **argv) {\n")
    fh.write("  uint32_t debug_en = 0;\n")
    fh.write("  hdl_hvl_api = api;\n")
    fh.write("  Verilated::commandArgs(argc, argv);\n")
    fh.write("\n")
    fh.write("  for (uint32_t i=1; i<argc; i++) {\n")
    fh.write("    if (!strcmp(argv[i], \"+verilator.debug\")) {\n")
    fh.write("      debug_en = 1;\n")
    fh.write("    }\n")
    fh.write("  }\n")
    fh.write("  Verilated::traceEverOn(true);\n")
    fh.write("\n")
    fh.write("  if (debug_en) {\n")
    fh.write("    tfp = new VerilatedLxt2C();\n")
    fh.write("  }\n")
    fh.write("  top = new V" + self.top + "();\n")
    fh.write("\n")
    fh.write("  atexit(&vl_ase_hdl_atexit);\n")
    fh.write("\n")
    fh.write("  if (tfp) {\n")
    fh.write("    top->trace(tfp, 99);\n")
    fh.write("    tfp->open(\"simx.lxt\");\n")
    fh.write("  }\n")
    fh.write("\n")
    fh.write("  top->eval();\n")
    fh.write("  if (tfp) {\n")
    fh.write("    tfp->dump(timestamp);\n")
    fh.write("  }\n")
    fh.write("\n")
    fh.write("  return &hvl_hdl_api;\n")
    fh.write("}\n")
    fh.write("\n")
    fh.close()

  #******************************************************************
  #* generate_top_vl_ase()
  #******************************************************************
  def generate_top_vl_ase(self):
    fh = open(self.obj_dir + "/top_vl_ase.sv", "w");

    fh.write("module top_vl_ase;\n")
    fh.write("  import \"DPI-C\" context function int unsigned vl_ase_init(string obj_dir);\n")
    fh.write("  import \"DPI-C\" context task vl_ase_eval();\n")
    fh.write("  import \"DPI-C\" context function void vl_ase_close();\n")
    fh.write("\n")
    fh.write("  reg init = 0;\n")
    fh.write("\n")
    fh.write("  initial begin\n")
    fh.write("    automatic string obj_dir;\n");
    fh.write("    if (!$value$plusargs(\"OBJ_DIR=%s\", obj_dir)) begin\n")
    fh.write("      $display(\"FATAL: no +OBJ_DIR specified\");\n")
    fh.write("      $finish();\n")
    fh.write("    end\n")
    fh.write("    $display(\"--> vl_ase_init(%0s)\", obj_dir);\n")
    fh.write("    if (vl_ase_init(obj_dir) != 0) begin\n")
    fh.write("      $display(\"FATAL: failed to load VL library\");\n")
    fh.write("      $finish();\n")
    fh.write("    end\n")
    fh.write("    $display(\"<-- vl_ase_init(%0s)\", obj_dir);\n")
    fh.write("    forever begin\n")
    fh.write("      #10ns;\n")
    fh.write("      if (init == 0) begin\n")
    fh.write("        init <= 1;\n")
    fh.write("      end\n")
    fh.write("      vl_ase_eval();\n")
    fh.write("      #10ns;\n")
    fh.write("    end\n")
    fh.write("  end\n")
    fh.write("\n")
    fh.write("  final begin\n")
    fh.write("    $display(\"--> close\");\n")
    fh.write("    vl_ase_close();\n")
    fh.write("    $display(\"<-- close\");\n")
    fh.write("  end\n")
    fh.write("\n")
    
    fh.write("endmodule\n")

    fh.close()


  #******************************************************************
  #* find_bfms()
  #*
  #* Process the DPI functions to assemble them into collections
  #* based on the BFM with which they are associated
  #******************************************************************
  def find_bfms(self):
    
    while True:
      bfm_register = None

      for dpi in self.dpi_funcs:
        if dpi.name.endswith("_register_hdl"):
          bfm_register = dpi
          break
 
      if bfm_register == None:
        break
      else:
        bfm_name = bfm_register.name[:-len("_register_hdl")]

      bfm_i = bfm(bfm_name)

      for dpi in self.dpi_funcs:
        if dpi.name.startswith(bfm_name):
          bfm_i.dpi_funcs.append(dpi)

      for dpi in bfm_i.dpi_funcs:
        self.dpi_funcs.remove(dpi)

      self.bfms.append(bfm_i)    
   
    for b in self.bfms:
      print "BFM: " + b.bfm_name

    for dpi in self.dpi_funcs:
      print "Error: residual DPI function: " + dpi.name

  def process_function(self, is_export, ts):
    print "proces_function: "

    ret = self.parse_type(ts)
    params = []

    name = ts.next()

    if ts.next() != "(":
      print "Error: missing ("

    while True:
      print "Param Parse Begin: " + str(ts.peek())
      if ts.peek() == ")" or ts.peek() == None:
        break

      ptype = self.parse_type(ts)
      pname = ts.next()

      print "Param: " + str(ptype) + " " + str(pname)

      params.append(dpi_param(ptype, pname))

      if ts.peek() == ",":
        ts.next()

    return dpi_func(name, is_export, ret, params)
      

  def parse_type(self, ts):
    typename = []
    t = ts.next()

    if t == "void":
      typename.append(t)
    elif t == "unsigned":
      typename.append(t)
      typename.append(ts.next())
      if ts.peek() == "long":
          typename.append(ts.next())
    elif t == "const": # const char *
      typename.append(t)
      typename.append(ts.next())
    else:
      typename.append(t)
      
    if ts.peek() == "*":
      typename.append(ts.next())

    return dpi_type(typename)


def main():
  print "Hello from Main"
  obj_dir = "obj_dir"
  top = None
 
  i=1 
  while i < len(sys.argv):
      if sys.argv[i].startswith("-"):
        if sys.argv[i] == "-top":
          i=i+1
          top = sys.argv[i]
        else:
            print "Error: unknown option " + sys.argv[i]
            sys.exit(1)
      else:
        print "Error: unknown argument " + sys.argv[i]
        sys.exit(1)
      i=i+1
  
  proc = vl_ase(obj_dir, top)

  proc.read_dpi()
  proc.find_bfms()

  proc.generate()


if __name__ == "__main__":
  main()

