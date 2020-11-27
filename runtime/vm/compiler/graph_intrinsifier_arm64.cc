// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#include "vm/globals.h"  // Needed here to get TARGET_ARCH_ARM64.
#if defined(TARGET_ARCH_ARM64)

#include "vm/compiler/assembler/assembler.h"
#include "vm/compiler/graph_intrinsifier.h"

namespace dart {
namespace compiler {

#define __ assembler->

intptr_t GraphIntrinsifier::ParameterSlotFromSp() {
  return -1;
}

void GraphIntrinsifier::IntrinsicCallPrologue(Assembler* assembler) {
  COMPILE_ASSERT(IsAbiPreservedRegister(CODE_REG));
  COMPILE_ASSERT(!IsAbiPreservedRegister(ARGS_DESC_REG));
  COMPILE_ASSERT(IsAbiPreservedRegister(CALLEE_SAVED_TEMP));
  COMPILE_ASSERT(IsAbiPreservedRegister(CALLEE_SAVED_TEMP2));
  COMPILE_ASSERT(CALLEE_SAVED_TEMP != CODE_REG);
  COMPILE_ASSERT(CALLEE_SAVED_TEMP != ARGS_DESC_REG);
  COMPILE_ASSERT(CALLEE_SAVED_TEMP2 != CODE_REG);
  COMPILE_ASSERT(CALLEE_SAVED_TEMP2 != ARGS_DESC_REG);

  assembler->Comment("IntrinsicCallPrologue");
  assembler->mov(CALLEE_SAVED_TEMP, LR);
  assembler->mov(CALLEE_SAVED_TEMP2, ARGS_DESC_REG);
}

void GraphIntrinsifier::IntrinsicCallEpilogue(Assembler* assembler) {
  assembler->Comment("IntrinsicCallEpilogue");
  assembler->mov(LR, CALLEE_SAVED_TEMP);
  assembler->mov(ARGS_DESC_REG, CALLEE_SAVED_TEMP2);
}

#undef __

}  // namespace compiler
}  // namespace dart

#endif  // defined(TARGET_ARCH_ARM64)
