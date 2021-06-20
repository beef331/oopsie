import std/macros


proc getRefTypeImpl(obj: NimNode): NimNode = obj.getTypeImpl[0].getTypeImpl()

proc superImpl(obj: NimNode): NimNode =
  let impl = obj.getRefTypeImpl
  assert impl[1].kind == nnkOfInherit
  impl[1][0]

macro inherits*(a: typed): bool =
  ## Returns `true` if the type or object inherits from an object.
  var impl = a.getImpl
  result = newLit false
  if impl.kind == nnkNilLit:
    impl = a.getTypeImpl[0].getImpl
    result = newLit impl.kind == nnkTypeDef and impl[2].kind == nnkObjectTy and impl[2][1].kind == nnkOfInherit
  else:
    result = newLit impl.kind == nnkTypeDef and impl[2].kind == nnkRefTy and impl[2][0][1].kind == nnkOfInherit

type Inherits = concept c
  c.inherits

macro super*(obj: Inherits): untyped =
  ## Gets the parent of this `obj`
  runnableExamples:
    type 
      A = ref object of RootObj
      B = ref object of A
    assert B().super is A
    assert A().super is RootObj

  obj.superImpl

macro rootSuper*(obj: Inherits): untyped =
  ## Gets the root parent of this `obj`, 
  ## does not get `RootObj`
  runnableExamples:
    type 
      A = ref object of RootObj
      B = ref object of A
      C = ref object of B
    assert C().rootSuper is A
    assert B().rootSuper is A
    assert A().rootSuper is A
  var obj = obj
  if obj.kind == nnkObjConstr:
    obj = obj[0]
  if not obj.getRefTypeImpl[1][0].eqIdent("RootObj"):
    var sup = obj
    while not sup.getRefTypeImpl[1][0].eqIdent("RootObj"):
      sup = sup.superImpl
    result = sup
  else:
    result = obj

func getFields(child: NimNode): seq[NimNode] =
  let impl = child.getType[^1].getImpl
  for identDef in impl[^1][^1]:
    result.add identDef[0..^3]
  if not impl[^1][1][0].eqIdent("RootObj"):
    result.add getFields(impl[^1][1][0])

macro copy*[C: Inherits, P: Inherits](child: C, parent: P): untyped =
  ## Allows copying from a parent type to a child
  runnableExamples:
    type 
      A = ref object of RootObj
        a, b, c: int
      B = ref object of A
        d: float
    var
      a = A(a: 100, b: 200, c: 20)
      b = B()
    b.copy(a)
    assert b[] == B(a: 100, b: 200, c: 20)[]

  let fields = getFields(parent)
  result = newStmtList()
  result.add quote do:
    if `child`.isNil:
      new `child`
  for field in fields:
    let field = field.baseName
    result.add quote do:
      `child`.`field` = `parent`.`field`

macro copyAs*(parent: Inherits, child: typedesc, name: untyped): untyped =
  ## Duplicates an object into a new object of `child` with `name`
  runnableExamples:
    type 
      A = ref object of RootObj
        a, b, c: int
      B = ref object of A
        d: float
    var a = A(a: 100, b: 200, c: 20)
    a.copyAs(B, newVar)
    assert newVar[] == B(a: 100, b: 200, c: 20)[]

  let fields = getFields(parent)
  result = nnkObjConstr.newTree(child)
  for x in fields:
    result.add nnkExprColonExpr.newTree(x, newDotExpr(parent, x))
  result = newVarStmt(name, result)

proc caseImpl(stmt: NimNode): NimNode =
  let obj = stmt[0]
  result = nnkIfStmt.newTree
  for branch in stmt[1..^1]:
    if branch.kind != nnkElse:
      for cond in branch[0..^2]:
        let
          body = branch[^1].copyNimTree
          it = ident"it"
        body.insert 0, quote do:
          let `it` = `cond`(`obj`)
        result.add nnkElifBranch.newTree(nnkInfix.newTree(ident"of", obj, cond), body)
    else:
      result.add branch

when (NimMajor, NimMinor) < (1, 5):
  macro match*(obj: Inherits): untyped =
    ## A more ergonomic abstraction for nested elif branches.
    ## Injects `it` as the converted type internally.
    ## Else branch does not inject an `it`.
    runnableExamples:
      {.experimental: "caseStmtMacros".}
      type
        A = ref object of RootObj
        B = ref object of A
          a: int
      case A(B()): # This is an `A` held `B`
      of B:
        assert $(it[]) == "(a: 0)"
      else: discard

    caseImpl(obj)
else:
  macro `case`*(obj: Inherits): untyped =
    ## A more ergonomic abstraction for nested elif branches.
    ## Injects `it` as the converted type internally.
    ## Else branch does not inject an `it`.
    runnableExamples:
      {.experimental: "caseStmtMacros".}
      type
        A = ref object of RootObj
        B = ref object of A
          a: int
      case A(B()): # This is an `A` held `B`
      of B:
        assert $(it[]) == "(a: 0)"
      else: discard
    caseImpl(obj)