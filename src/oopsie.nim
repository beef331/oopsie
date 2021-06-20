import std/macros


proc getRefTypeImpl(obj: NimNode): NimNode = obj.getTypeImpl[0].getTypeImpl()

proc superImpl(obj: NimNode): NimNode =
  let impl = obj.getRefTypeImpl
  assert impl[1].kind == nnkOfInherit
  impl[1][0]

macro super*(obj: ref object): untyped =
  ## Gets the parent of this `obj`
  runnableExamples:
    type 
      A = ref object of RootObj
      B = ref object of A
    assert B().super is A
    assert A().super is RootObj

  obj.superImpl

macro rootSuper*(obj: ref object): untyped =
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

macro copy*(child: ref object, parent: ref object): untyped =
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

macro copyAs*(parent: ref object, child: typedesc, name: untyped): untyped =
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