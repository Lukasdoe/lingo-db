set(LLVM_TARGET_DEFINITIONS ArrowBase.td)
mlir_tablegen(ArrowOpsDialect.h.inc -gen-dialect-decls --dialect=arrow)
mlir_tablegen(ArrowOpsDialect.cpp.inc -gen-dialect-defs --dialect=arrow)
mlir_tablegen(ArrowOpsTypes.h.inc --gen-typedef-decls --typedefs-dialect=arrow)
mlir_tablegen(ArrowOpsTypes.cpp.inc --gen-typedef-defs --typedefs-dialect=arrow)
set(LLVM_TARGET_DEFINITIONS ArrowOps.td)
mlir_tablegen(ArrowOps.h.inc -gen-op-decls)
mlir_tablegen(ArrowOps.cpp.inc -gen-op-defs)
add_public_tablegen_target(MLIRArrowOpsIncGen)
add_dependencies(build_includes MLIRArrowOpsIncGen)
add_mlir_doc(ArrowOps ArrowDialect Arrow/ -gen-dialect-doc --dialect=arrow)
