import unittest
import oopsie

test "Super":
  type 
    A = ref object of RootObj
    B = ref object of A
  assert B().super is A
  assert A().super is RootObj

test "Root Super":
  type 
    A = ref object of RootObj
    B = ref object of A
    C = ref object of B
  assert C().rootSuper is A
  assert B().rootSuper is A
  assert A().rootSuper is A


test "Copy":
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



test "Copy As":
  type 
    A = ref object of RootObj
      a, b, c: int
    B = ref object of A
      d: float
  var a = A(a: 100, b: 200, c: 20)
  a.copyAs(B, newVar)
  assert newVar[] == B(a: 100, b: 200, c: 20)[]

test "Case Stmt":
  type
    A = ref object of RootObj
    B = ref object of A
      a: int
  case A(B()):
  of B:
    assert $(it[]) == "(a: 0)"
  else: discard