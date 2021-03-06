(* Definitions for sets. *)

exception TODO

(* An interface for set modules *)
module type SET = 
sig
  type elt  (* type of elements in the set *)
  type set  (* abstract type for the set *)

  val empty : set

  val is_empty : set -> bool

  val insert : elt -> set -> set

  (* same as insert x empty *)
  val singleton : elt -> set

  val union : set -> set -> set
  val intersect : set -> set -> set

  (* remove an element from the set -- if the
   * element isn't present, does nothing. *)
  val remove : elt -> set -> set

  (* returns true iff the element is in the set *)
  val member : set -> elt -> bool

  (* chooses some member from the set, removes it 
   * and returns that element plus the new set.  
   * If the set is empty, returns None. *)
  val choose : set -> (elt * set) option

  (* fold a function across the elements of the set
   * in some unspecified order. *)
  val fold : (elt -> 'a -> 'a) -> 'a -> set -> 'a

  (* functions to convert our types to a string. useful for debugging. *)
  val string_of_set : set -> string
  val string_of_elt : elt -> string

  (* runs our tests. See "Testing" in the assignment web page *)
  val run_tests : unit -> unit
end



(* parameter to Set modules -- we must pass in some 
 * type for the elements of a set, a comparison
 * function, and a way to stringify it.
 *)
module type COMPARABLE = 
sig
  type t
  val compare : t -> t -> Order.order
  val string_of_t : t -> string

  (* The functions below are used for testing.
     See "Testing" in the assignment web page *)

  (* Generate a value of type t. The same t is always returned *)
  val gen : unit -> t

  (* Generate a random value of type t. *)
  val gen_random : unit -> t

  (* Generate a t greater than the argument. *)
  val gen_gt : t -> unit -> t

  (* Generate a t less than the argument. *)
  val gen_lt : t -> unit -> t

  (* Generate a t between the two arguments. Return None if no such
   * t exists. *)
  val gen_between : t -> t -> unit -> t option
end



(* An example implementation of our COMPARABLE signature. Use this
 * struct for testing. *)
module IntComparable : COMPARABLE =
struct
  open Order
  type t = int
  let compare x y = if x < y then Less else if x > y then Greater else Eq
  let string_of_t = string_of_int
  let gen () = 0
  let gen_random =
    let _ = Random.self_init () in
    (fun () -> Random.int 10000)
  let gen_gt x () = x + 1
  let gen_lt x () = x - 1
  let gen_between x y () = 
    let (lower, higher) = (min x y, max x y) in
    if higher - lower < 2 then None else Some (higher - 1)
end



(* A simple, list-based implementation of sets. *)
module ListSet(C: COMPARABLE) : (SET with type elt = C.t) = 
struct
  open Order
  type elt = C.t 
  type set = elt list

  (* INVARIANT: sorted, no duplicates *)
  let empty = []
  let is_empty xs = 
    match xs with 
      | [] -> true
      | _ -> false
  let singleton x = [x]
  let rec insert x xs = 
    match xs with 
      | [] -> [x]
      | y::ys -> (match C.compare x y with 
          | Greater -> y::(insert x ys)
          | Eq -> xs
          | Less -> x::xs)

  let union xs ys = List.fold_right insert xs ys
  let rec remove y xs = 
    match xs with 
      | [] -> []
      | x::xs1 -> (match C.compare y x with 
          | Eq -> xs1
          | Less -> xs
          | Greater -> x::(remove y xs1))

  let rec intersect xs ys = 
    match xs, ys with 
      | [], _ -> []
      | _, [] -> []
      | xh::xt, yh::yt -> (match C.compare xh yh with 
          | Eq -> xh::(intersect xt yt)
          | Less -> intersect xt ys
          | Greater -> intersect xs yt)

  let rec member xs x = 
    match xs with 
      | [] -> false
      | y::ys -> (match C.compare x y with
          | Eq -> true
          | Greater -> member ys x
          | Less -> false)

  let choose xs = 
    match xs with 
      | [] -> None
      | x::rest -> Some (x,rest)
  let fold f e = List.fold_left (fun a x -> f x a) e 
    
  let string_of_elt = C.string_of_t
  let string_of_set (s: set) : string = 
    let f = (fun y e -> y ^ "; " ^ C.string_of_t e) in
    "set([" ^ (List.fold_left f "" s) ^ "])"


  (****************************************************************)
  (* Tests for our ListSet functor                                *)
  (* These are just examples of tests, your tests should be a lot *)
  (* more thorough than these.                                    *)
  (****************************************************************)

  (* adds a list of (key,value) pairs in left-to-right order *)
  let insert_list (d: set) (lst: elt list) : set = 
    List.fold_left (fun r k -> insert k r) d lst

  let rec generate_random_list (size: int) : elt list =
    if size <= 0 then []
    else (C.gen_random()) :: (generate_random_list (size - 1))

  let test_insert () =
    let elts = generate_random_list 100 in
    let s1 = insert_list empty elts in
    List.iter (fun k -> assert(member s1 k)) elts ;
    ()

  let test_remove () =
    let elts = generate_random_list 100 in
    let s1 = insert_list empty elts in
    let s2 = List.fold_right (fun k r -> remove k r) elts s1 in
    List.iter (fun k -> assert(not (member s2 k))) elts ;
    ()

  let test_union () =
    ()

  let test_intersect () =
    ()

  let test_member () =
    ()

  let test_choose () =
    ()

  let test_fold () =
    ()

  let test_is_empty () =
    ()

  let test_singleton () =
    ()

  let run_tests () = 
    test_insert () ;
    test_remove () ;
    test_union () ;
    test_intersect () ;
    test_member () ;
    test_choose () ;
    test_fold () ;
    test_is_empty () ;
    test_singleton () ;
    ()

end


(******************************************************************)
(* DictSet: a functor that creates a SET by calling our           *)
(* Dict.Make functor                                              *)
(******************************************************************)

module DictSet(C : COMPARABLE) : (SET with type elt = C.t) = 
struct
  module D = Dict.Make(struct
      type key = C.t
      type value = C.t list
      
      let compare x y = C.compare x y 
      let string_of_key x = C.string_of_t x
      let string_of_value xs =     
        let f = (fun y e -> y ^ "; " ^ C.string_of_t e) in
        "set([" ^ (List.fold_left f "" xs) ^ "])"

      let gen_key () = C.gen ()
      let gen_key_random () = C.gen_random ()
      let gen_key_gt x () = C.gen_gt x ()
      let gen_key_lt x () = C.gen_lt x ()
      let gen_key_between x y () = C.gen_between x y ()
      let gen_value () = []
      let gen_pair () = (gen_key(), gen_value())
  end)

  (* type elt = C.t *)
  (* type set = C.t list *)

  type elt = D.key
  type set = D.dict

  let empty = D.empty
  let is_empty (xs: set) = 
    if xs == D.empty then true else false
  let singleton (x: elt) : set = D.insert empty x []
  let insert x xs : set = D.insert xs x []
  let union xs ys : set =
    let rec helper d union : set = 
      (match D.choose d with
      | Some (k,v,d')-> 
        let union' = D.insert union k v in
          helper d' union'
      | None -> union)
    in helper xs ys
  let intersect xs ys : set = 
    let rec helper s1 s2 intersection : set = 
      (match D.choose s1 with 
      |Some (k,v,s1') -> 
        if D.member s2 k then 
          let intersection' = D.insert intersection k v in 
          helper s1' s2 intersection'
        else
          helper s1' s2 intersection
      |None->intersection)
    in
    helper xs ys D.empty
  let remove x xs : set = D.remove xs x
  let member xs x : bool = D.member xs x 
  let choose xs : (elt * set) option= 
    match D.choose xs with
    |None -> None
    |Some (k,v,d)->Some (k,d)
  let fold f x : set -> 'a = 
    fun xs ->
      let rec helper f x xs = 
        (match D.choose xs with
        |None -> x
        |Some(k,v,d)->
          helper f (f k x) d)
      in helper f x xs

  let string_of_elt = D.string_of_key
  let string_of_set s = D.string_of_dict s
  
  let test_is_empty () = 
    assert(is_empty D.empty)

  let test_singleton () = 
    let xs = singleton (C.gen ()) in
    assert (not (is_empty xs))

  let random_set = 
    let xs = singleton (C.gen_random()) in 
    let xs' = insert (C.gen_random()) xs in 
    let xs'' = insert (C.gen_random()) xs' in
    xs''

  let test_fold () = 
    let emp = empty in
    let clone = fold (insert) emp in
    assert ((clone random_set) == random_set)

  let run_tests () = 
    test_is_empty () ;
    test_singleton () ;
    test_fold () ;
    ()

  end

  (****************************************************************)
  (* Tests for our DictSet functor                                *)
  (* Use the tests from the ListSet functor to see how you should *)
  (* write tests. However, you must write a lot more              *)
  (* comprehensive tests to test ALL your functions.              *)
  (****************************************************************)

  (* add your test functions to run_tests *)
  (*
  let run_tests () = 
    ()
  *)

(******************************************************************)
(* Run our tests.                                                 *)
(******************************************************************)

(* Create a set of ints using our ListSet functor. *)
module IntListSet = ListSet(IntComparable) ;;
IntListSet.run_tests();;

(* Create a set of ints using our DictSet functor
 * 
 * Uncomment out the lines below when you are ready to test your
 * 2-3 dict set implementation *)
(*
module IntDictSet = DictSet(IntComparable) ;;
IntDictSet.run_tests();;
*)


(******************************************************************)
(* Make: a functor that creates a SET by calling our              *)
(* ListSet or DictSet functors                                    *)
(******************************************************************)
module Make(C : COMPARABLE) : (SET with type elt = C.t) = 
  (* Change this line to use our dictionary implementation when your are 
   * finished. *)
  DictSet (C)
  (* DictSet (C) *)

