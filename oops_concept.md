# OOP Concepts for Microsoft Technical Interview Preparation

> **Target Audience:** Candidates preparing for Microsoft Software Engineering Technical Interviews (L59-L62 / SDE I & II).
> **Focus:** Object-Oriented Programming principles, modern C++ (C++11 through C++20) behavior, low-level mechanics, design trade-offs, and common interview pitfalls.

---

# Table of Contents
1. [OOP Mental Model](#1-oop-mental-model)
2. [Core OOP Concepts](#2-core-oop-concepts)
3. [The Four Pillars of OOP](#3-the-four-pillars-of-oop)
4. [Virtual Functions — Deep Dive](#4-virtual-functions--deep-dive)
5. [Constructors and Destructors](#5-constructors-and-destructors)
6. [Copy & Move Semantics (Rule of 0/3/5)](#6-copy--move-semantics-rule-of-035)
7. [The `this` Pointer](#7-the-this-pointer)
8. [Static Members](#8-static-members)
9. [Friend Functions and Friend Classes](#9-friend-functions-and-friend-classes)
10. [Access Specifiers & Inheritance Mechanics](#10-access-specifiers--inheritance-mechanics)
11. [Abstract Classes and Interfaces](#11-abstract-classes-and-interfaces)
12. [Association vs Aggregation vs Composition](#12-association-vs-aggregation-vs-composition)
13. [Inheritance vs Composition](#13-inheritance-vs-composition)
14. [Overloading vs Overriding vs Hiding](#14-overloading-vs-overriding-vs-hiding)
15. [Virtual Destructors](#15-virtual-destructors)
16. [Multiple Inheritance & The Diamond Problem](#16-multiple-inheritance--the-diamond-problem)
17. [Object Slicing](#17-object-slicing)
18. [Casting Mechanics (Upcasting, Downcasting, RTTI)](#18-casting-mechanics-upcasting-downcasting-rtti)
19. [Operator Overloading](#19-operator-overloading)
20. [Const Correctness in OOP](#20-const-correctness-in-oop)
21. [`struct` vs `class` in C++](#21-struct-vs-class-in-c)
22. [SOLID Principles](#22-solid-principles)
23. [Dependency Injection, Coupling & Cohesion](#23-dependency-injection-coupling--cohesion)
24. [Immutability & Thread Safety](#24-immutability--thread-safety)
25. [Object Relationships Summary](#25-object-relationships-summary)
26. [Memory Management & RAII](#26-memory-management--raii)
27. [Smart Pointers & OOP](#27-smart-pointers--oop)
28. [SOLID & OOP System Design Interview Framework](#28-solid--oop-system-design-interview-framework)
29. [50 Microsoft-Style OOP Interview Questions](#29-50-microsoft-style-oop-interview-questions)
30. [20 C++ Output-Based OOP Snippets](#30-20-c-output-based-oop-snippets)
31. [Interview Traps](#31-interview-traps)
32. [OOP Quick Revision & Comparison Tables](#32-oop-quick-revision--comparison-tables)
33. [How to Answer OOP Questions in an Interview](#33-how-to-answer-oop-questions-in-an-interview)
34. [If I Have Only 1 Hour](#34-if-i-have-only-1-hour)

---

# 1. OOP Mental Model

🟢 **Fundamental**

### What OOP Solves
Procedural programming groups data into structures and behavior into functions operating on those structures. As systems scale, procedural designs suffer from **unbounded state mutation** and **tight coupling**: any function can potentially mutate any structure from anywhere. 

Object-Oriented Programming (OOP) addresses this by **colocating state with the operations allowed to mutate that state**, creating boundary walls around domain concepts.

### Why OOP Exists & When It Is Useful
* **Domain Modeling:** Maps software directly to entities with clear boundaries (e.g., File Systems, Windowing Managers, Game Entities, Network Sockets).
* **Managing Complexity:** Encapsulates state behind strict contracts so developers reason about isolated components rather than global state.
* **Extensibility:** Enables system expansion without modifying existing call sites via dynamic polymorphism.

### When OOP May Be Unnecessary / Counterproductive
* **Data Pipelines / Transforms:** Pure functional paradigms or data-oriented design (DOD) are superior for SIMD optimizations, cache-friendly batch processing, and continuous data streams.
* **Simple Utility Logic:** Wrapping stateless functions inside artificial "Utility Classes" introduces boilerplate without architectural benefit.

### Architectural Value
| Metric | How OOP Delivers It |
| :--- | :--- |
| **Complexity** | Limits state visibility; changes inside a class boundary do not cascade globally. |
| **Maintainability** | Encapsulates implementation details behind fixed public interfaces. |
| **Scalability** | Allows teams to work concurrently on separate classes against pre-agreed contracts. |
| **Reusability** | Enables generic abstractions, composition, and inheritance patterns. |
| **Extensibility** | Systems can be expanded (Open/Closed Principle) via polymorphic interfaces. |
| **Collaboration** | Establishes clear domain ownership across software components. |

> [!IMPORTANT]
> **OOP is NOT simply "the four pillars".** Encapsulation, abstraction, inheritance, and polymorphism are language mechanisms. Fundamentally, OOP is a design methodology centered around messaging between autonomous objects, maintaining invariants, establishing domain boundaries, and defining clean interfaces.

---

# 2. Core OOP Concepts

🟢 **Fundamental**

## 2.1 Class
A **class** is a user-defined blueprint or type that specifies the layout of memory (data members) and the operations (member functions) that act upon instances of that type.

### Access Specifiers
* **`public`**: Accessible from any scope where the object is visible.
* **`private`**: Accessible *only* by member functions and `friend` scope of the class.
* **`protected`**: Accessible by member functions/friends of the class *and* derived classes.

### Default Access Controls
* **`class`**: Default access specifier and default inheritance visibility are `private`.
* **`struct`**: Default access specifier and default inheritance visibility are `public`.

```cpp
#include <iostream>

class BankAccount {
    // Private data members (default for class)
    double balance; 

public:
    // Constructor
    explicit BankAccount(double initial_balance) : balance(initial_balance) {}

    // Member function
    void deposit(double amount) {
        if (amount > 0) {
            balance += amount;
        }
    }

    // Const member function (reads state, cannot modify data members)
    double getBalance() const {
        return balance;
    }
};
```

## 2.2 Object
An **object** is an instantiated region of storage possessing **state** (data member values), **behavior** (member functions), and **identity** (a unique address in memory).

### Object Lifetime & Storage Allocation
```cpp
// 1. Stack Allocation (Automatic Storage Duration)
// Memory allocated on function stack frame. Automatically destroyed on scope exit.
BankAccount stackAcc(1000.0);

// 2. Heap Allocation (Dynamic Storage Duration)
// Memory allocated on free store via `new`. Lifetime manually managed (or via Smart Pointers).
BankAccount* heapAcc = new BankAccount(2000.0);

// Memory must be explicitly freed to prevent memory leaks
delete heapAcc; 
heapAcc = nullptr;
```

---

# 3. The Four Pillars of OOP

🔴 **High Priority / Frequently Tested**

```
             ┌─────────────────────────────────────────┐
             │            FOUR PILLARS OF OOP          │
             └────────────────────┬────────────────────┘
       ┌──────────────────┬───────┴──────────┬──────────────────┐
       ▼                  ▼                  ▼                  ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│Encapsulation │   │ Abstraction  │   │ Inheritance  │   │ Polymorphism │
│  (Data +     │   │ (Interface vs│   │ (Reusability │   │(Compile-time │
│ Data Hiding) │   │Impl Details) │   │& Taxonomy)   │   │ & Runtime)   │
└──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘
```

## 3.1 Encapsulation
Encapsulation is the bundling of data and the methods that operate on that data into a single unit (class), while restricting direct access to internal state (data hiding).

### Why Exposing Data Publicly is Dangerous
1. **Broken Invariants:** Direct public access lets external code put the object into an invalid state (e.g., negative bank balance, invalid array index).
2. **Loss of Flexibility:** Changing data representation (e.g., renaming variables or converting units) breaks all consuming client code.
3. **No Synchronization Points:** Prevents inserting validation, logging, thread-locks, or side-effects during mutation.

```cpp
class BankAccount {
private:
    double balance; // Internal state hidden

public:
    explicit BankAccount(double b) : balance(b >= 0 ? b : 0) {}

    void deposit(double amount) {
        if (amount <= 0) throw std::invalid_argument("Deposit must be positive");
        balance += amount; // Validated mutation point
    }

    double getBalance() const { return balance; }
};
```

⭐ **Interview Trap:** "Is encapsulation the same as data hiding?"
* **Answer:** **No.** Data hiding is a *technique* used inside encapsulation. Encapsulation is the *act of grouping* data and methods into a single coherent entity. Data hiding (via `private`/`protected`) restricts external access to those details. You can have encapsulation without data hiding (e.g., a C-style struct grouping public variables), but robust OOP combines both.

## 3.2 Abstraction
Abstraction is the design-level technique of exposing **what** an object does via a clean interface while hiding **how** it accomplishes it.

```cpp
// Abstract interface exposed to consumers
class IPaymentProcessor {
public:
    virtual ~IPaymentProcessor() = default;
    virtual bool processPayment(double amount) = 0; // Pure virtual interface
};

class StripePaymentProcessor : public IPaymentProcessor {
public:
    bool processPayment(double amount) override {
        // Complex HTTP handshake, encryption, API payloads hidden from caller
        return true;
    }
};
```

| Feature | Encapsulation | Abstraction |
| :--- | :--- | :--- |
| **Focus** | Implementation level (protection & structural grouping). | Design level (interface representation). |
| **Goal** | Hides *internal state* behind methods to maintain object integrity. | Hides *complexity* by showing only relevant behavioral contracts. |
| **Mechanism** | Access specifiers (`private`, `protected`). | Abstract classes, Pure Virtual functions, interfaces. |

## 3.3 Inheritance
Inheritance allows a derived class to acquire the properties (data members) and behaviors (member functions) of a base class, establishing an **is-a** relationship.

### Types of Inheritance
1. **Single Inheritance:** `Derived` inherits directly from `Base`.
2. **Multilevel Inheritance:** `C` inherits from `B`, which inherits from `A`.
3. **Multiple Inheritance:** `Derived` inherits directly from `BaseA` and `BaseB`.
4. **Hierarchical Inheritance:** `Derived1` and `Derived2` both inherit from `Base`.
5. **Hybrid Inheritance:** A combination of two or more inheritance modes (e.g., Diamond Structure).

### Member Accessibility Under Inheritance Modes
| Base Member Visibility | `public` Inheritance | `protected` Inheritance | `private` Inheritance |
| :--- | :--- | :--- | :--- |
| **`public`** | `public` in Derived | `protected` in Derived | `private` in Derived |
| **`protected`** | `protected` in Derived | `protected` in Derived | `private` in Derived |
| **`private`** | Hidden (inaccessible) | Hidden (inaccessible) | Hidden (inaccessible) |

> [!CAUTION]
> Private base members are physically stored in the memory layout of derived class instances, but they are inaccessible to derived class member functions.

```cpp
class Base {
public:    int pub = 1;
protected: int pro = 2;
private:   int prv = 3;
};

class DerivedPublic : public Base {
    void test() {
        pub = 10; // OK
        pro = 20; // OK
        // prv = 30; // ERROR: Private in Base is inaccessible
    }
};
```

## 3.4 Polymorphism
Polymorphism ("many forms") allows entities of different types to respond to the same function caller interface in unique ways.

### Compile-time Polymorphism (Static Binding)
Resolved during compilation via function signature matching or template instantiation.
* **Function Overloading:** Same function name, distinct parameter lists.
* **Operator Overloading:** Custom behavior for language operators on user types.
* **Templates (Generic Programming):** Parametric polymorphism generating monomorphized code at compile time.

### Runtime Polymorphism (Dynamic Binding)
Resolved at runtime via pointer/reference dispatch through virtual function lookups.
* **Method Overriding:** A derived class replaces a base class virtual method's implementation.
* **Dynamic Dispatch Mechanics:** Executed via `vptr` and `vtable`.

---

# 4. Virtual Functions — Deep Dive

🔴 **High Priority / Frequently Tested**

## Mechanics of Dynamic Binding
When a member function is marked `virtual`, the compiler shifts dispatch logic from **static resolution** (determined at compile time based on the pointer/reference static type) to **dynamic binding** (determined at runtime based on the actual object type).

```cpp
#include <iostream>

class Animal {
public:
    virtual void speak() const { std::cout << "Animal sound\n"; }
    void identity() const { std::cout << "I am Animal\n"; }
    virtual ~Animal() = default;
};

class Dog : public Animal {
public:
    void speak() const override { std::cout << "Bark!\n"; }
    void identity() const { std::cout << "I am Dog\n"; }
};

int main() {
    Dog dog;
    Animal* ptr = &dog;

    ptr->speak();    // Prints: "Bark!" (Dynamic binding via virtual lookup)
    ptr->identity(); // Prints: "I am Animal" (Static binding based on pointer type)
}
```

## Low-Level Compiler Mechanics: `vtable` and `vptr`
*(Implementation Detail: Standard C++ does not strictly mandate dynamic dispatch to be implemented via vtables, but almost all major modern compilers—MSVC, GCC, Clang—use this exact model).*

```
           [ Dog Object in Heap/Stack ]               [ Dog Class vtable ]
           ┌──────────────────────────┐               ┌──────────────────┐
           │  vptr (Pointer to vtable)├──────────────►│ &Dog::speak      │
           ├──────────────────────────┤               │ &Animal::getType │
           │  Animal::data_member     │               └──────────────────┘
           ├──────────────────────────┤
           │  Dog::data_member        │
           └──────────────────────────┘
```

1. **`vtable` (Virtual Table):** A static lookup table generated per class containing dynamic virtual function code addresses.
2. **`vptr` (Virtual Pointer):** A hidden pointer inserted by the compiler as the first member of any object instantiated from a class with at least one virtual function. 
3. **Cost of Virtual Functions:**
   * **Memory:** +1 pointer size (`4` or `8` bytes) per instance for `vptr`. 1 `vtable` per class in the read-only executable data segment.
   * **Execution Overhead:** Destroys compiler inlining optimizations. Introduces double-pointer dereferences: `*(ptr->vptr[slot_index])()`.

## Keywords: `virtual`, `override`, `final`
* **`virtual`**: Marks a method eligible for dynamic dispatch in derived classes.
* **`override`** *(C++11)*: Forces compiler validation that the method signature matches a base virtual function exactly. Prevents subtle hiding bugs!
* **`final`** *(C++11)*: Stops further overriding in derived classes or prevents inheriting from a class (`class Base final {}`).

---

# 5. Constructors and Destructors

🟡 **Important**

## Constructors
Constructors initialize object storage to maintain invariants before usage.

```cpp
class Vector {
    double* data;
    size_t size;

public:
    // 1. Default Constructor
    Vector() : data(nullptr), size(0) {}

    // 2. Parameterized Constructor
    explicit Vector(size_t s) : size(s), data(new double[s]{}) {}

    // 3. Member Initialization List (Executes before constructor body)
    // Initialization lists are mandatory for: const members, references, base classes without default constructors.
    
    // 4. Delegating Constructor (C++11)
    Vector() : Vector(0) {} // Delegates to Parameterized constructor
};
```

⭐ **Interview Trap:** Why use `explicit` on single-argument constructors?
* **Answer:** Prevents implicit type conversions by the compiler.
```cpp
void printVector(const Vector& v);

// WITHOUT explicit:
// printVector(10); // Compiles implicitly! Creates temporary Vector(10). Often a catastrophic bug.

// WITH explicit:
// printVector(10); // COMPILE ERROR! Must call printVector(Vector(10)).
```

## Destructors
Destructors perform cleanup when an object reaches the end of its lifetime. They take no parameters and cannot be overloaded.

```cpp
class ResourceHandler {
    int* resource;
public:
    ResourceHandler() : resource(new int(42)) {}
    ~ResourceHandler() { delete resource; } // Destructor cleans dynamic memory
};
```

---

# 6. Copy & Move Semantics (Rule of 0/3/5)

🔴 **High Priority / Frequently Tested**

## Shallow Copy vs Deep Copy
* **Shallow Copy:** Bitwise copy of data members (`memcpy`). Pointers copied directly point to the *same memory block*, triggering **double-free errors** on destruction.
* **Deep Copy:** Allocates new memory resources and duplicates the underlying data.

```cpp
class DynamicArray {
    int* data;
    size_t size;

public:
    DynamicArray(size_t s) : size(s), data(new int[s]) {}
    ~DynamicArray() { delete[] data; }

    // Shallow Copy (Default Compiler Copy Constructor):
    // DynamicArray(const DynamicArray& other) : size(other.size), data(other.data) {}

    // Deep Copy Constructor:
    DynamicArray(const DynamicArray& other) : size(other.size), data(new int[other.size]) {
        std::copy(other.data, other.data + size, data);
    }

    // Deep Copy Assignment Operator:
    DynamicArray& operator=(const DynamicArray& other) {
        if (this == &other) return *this; // Self-assignment check!

        int* new_data = new int[other.size]; // Exception-safe allocation
        std::copy(other.data, other.data + other.size, new_data);

        delete[] data; // Free old resource
        data = new_data;
        size = other.size;
        return *this;
    }
};
```

## Move Semantics (C++11)
Move semantics transfer resource ownership from rvalue temporary objects to target instances without deep copying memory.

```cpp
// Move Constructor
DynamicArray(DynamicArray&& other) noexcept 
    : data(other.data), size(other.size) {
    other.data = nullptr; // Leave source object in safe, reset state
    other.size = 0;
}

// Move Assignment Operator
DynamicArray& operator=(DynamicArray&& other) noexcept {
    if (this == &other) return *this;

    delete[] data; // Release current resource

    data = other.data; // Steal pointer ownership
    size = other.size;

    other.data = nullptr; // Reset source object
    other.size = 0;
    return *this;
}
```

## Rule of 0 / 3 / 5

```
              ┌──────────────────────────────────────────────┐
              │           RESOURCE MANAGEMENT RULES          │
              └──────────────────────┬───────────────────────┘
          ┌──────────────────────────┴──────────────────────────┐
          ▼                                                     ▼
┌──────────────────┐                                  ┌──────────────────┐
│   RULE OF ZERO   │                                  │   RULE OF 3 / 5  │
├──────────────────┤                                  ├──────────────────┤
│ Custom resource  │                                  │ Custom memory /  │
│ cleanup omitted. │                                  │ low-level handle │
│ Smart pointers & │                                  │ ownership managed│
│ STL handle it.   │                                  │ manually.        │
└──────────────────┘                                  └──────────────────┘
```

* **Rule of 3 (Pre-C++11):** If a class requires a custom **Destructor**, **Copy Constructor**, or **Copy Assignment Operator**, it almost certainly requires all three.
* **Rule of 5 (C++11+):** Adding **Move Constructor** and **Move Assignment Operator** to the Rule of 3 for efficiency.
* **Rule of 0:** Design classes so that custom special member functions are unnecessary (use `std::unique_ptr`, `std::vector`, `std::string` to automate lifetime).

---

# 7. The `this` Pointer

🟢 **Fundamental**

`this` is an implicit constant pointer (`Type* const this`) passed as a hidden argument to non-static member functions pointing to the calling object instance.

### Primary Uses
1. **Resolving Scope Ambiguity:** `this->age = age;`
2. **Method Chaining (Fluent Interface):** Returning `*this` by reference (`return *this;`).
3. **Self-Assignment Verification:** `if (this == &other) return *this;`

```cpp
class Builder {
    int value = 0;
public:
    Builder& setValue(int v) {
        this->value = v; // Scope resolution
        return *this;    // Method chaining enable
    }
};
```

---

# 8. Static Members

🟡 **Important**

Static members belong to the class scope itself rather than individual object instances.

## Static Data Members
* Shared across all instances of the class.
* Exist in global memory segment for the entire program duration.
* Must be defined out-of-line outside the class declaration (unless declared `inline` in C++17).

## Static Member Functions
* Can be called without instantiating an object (`Class::Function()`).
* **Do NOT have a `this` pointer.**
* **Can ONLY directly access static data members and static functions.** They cannot directly dereference instance variables without an explicit object parameter.

```cpp
class IDGenerator {
    static int next_id; // Declaration
public:
    static int generateID() {
        return ++next_id; // Accessing static data member
    }
};

int IDGenerator::next_id = 0; // Definition out-of-line
```

---

# 9. Friend Functions and Friend Classes

🟡 **Important**

The `friend` keyword explicitly overrides class access boundaries, giving non-member functions or external classes full access to `private` and `protected` members.

```cpp
class Matrix; // Forward declaration

class Vector {
    double x, y;
public:
    Vector(double x, double y) : x(x), y(y) {}
    friend class Matrix; // Friend Class
    friend Vector multiply(const Matrix& m, const Vector& v); // Friend Function
};
```

### Strategic Implications
* **Advantages:** Facilitates tight coupling when syntax dictates non-member usage (e.g., streaming operators `operator<<`).
* **Disadvantages:** Breaks strict encapsulation and data hiding.
* **Key Properties:** Friendship is **not symmetric** (if A is friend of B, B is not automatically friend of A), **not transitive** (if A is friend of B, and B of C, A is not friend of C), and **not inherited**.

---

# 10. Access Specifiers & Inheritance Mechanics

🟡 **Important**

### Detailed Inheritance Visibility Matrix
```cpp
class Parent {
public:    int pub = 1;
protected: int pro = 2;
private:   int prv = 3;
};

class ChildPublic : public Parent {
    // pub -> public
    // pro -> protected
    // prv -> Inaccessible
};

class ChildProtected : protected Parent {
    // pub -> protected
    // pro -> protected
    // prv -> Inaccessible
};

class ChildPrivate : private Parent {
    // pub -> private
    // pro -> private
    // prv -> Inaccessible
};
```

---

# 11. Abstract Classes and Interfaces

🔴 **High Priority / Frequently Tested**

* **Pure Virtual Function:** A virtual function declared with `= 0`. Indicates the method has no default implementation in the base and *must* be overridden by concrete derived classes.
* **Abstract Class:** A class containing at least one pure virtual function. **Cannot be instantiated direct objects.**
* **Interface Concept in C++:** C++ has no native `interface` keyword. Interfaces are created via **pure abstract classes** containing *only* pure virtual functions, no state (no non-static data members), and a virtual default destructor.

```cpp
// Pure Interface in C++
class ILogger {
public:
    virtual ~ILogger() = default;
    virtual void log(const std::string& msg) = 0; // Pure virtual
};
```

### Concrete Questions
* **Can abstract classes have constructors?** **Yes.** They run when derived class instances are constructed to initialize base data members.
* **Can abstract classes have implemented methods?** **Yes.** Pure virtual functions can even have a default definition body provided out-of-line!

---

# 12. Association vs Aggregation vs Composition

🔴 **High Priority / Frequently Tested**

```
Association (uses-a) ────────► Aggregation (has-a) ────────► Composition (part-of)
[Independent lifetimes]       [Weak ownership/Shared]        [Strict ownership/Co-dependent]
```

| Relationship | Ownership | Lifetime Dependency | C++ Implementation Pattern | Example |
| :--- | :--- | :--- | :--- | :--- |
| **Association** | None ("uses-a") | Completely independent | Pointer/Reference parameter in method calls | `Driver` uses `Car` |
| **Aggregation** | Weak ("has-a") | Independent (Child outlives Parent) | Raw Pointers, `std::weak_ptr`, or `std::shared_ptr` | `Department` has `Professors` |
| **Composition** | Strong ("part-of") | Co-dependent (Parent owns Child lifetime) | Direct values, `std::unique_ptr` member variables | `House` composed of `Rooms` |

```cpp
// Composition Example
class Engine {};
class Car {
    Engine engine; // Lifetime of Engine bound strictly to Car
};

// Aggregation Example
class Teacher {};
class Department {
    std::vector<Teacher*> teachers; // Department destroyed != Teachers destroyed
};
```

---

# 13. Inheritance vs Composition

🔴 **High Priority / Frequently Tested**

> [!TIP]
> **Prefer Composition over Inheritance.** (Gang of Four principle).

### Structural Comparison
* **Inheritance ("Is-A"):** White-box reuse. Exposes internal base details to derived classes. Polymorphic, but tightly coupled at compile time.
* **Composition ("Has-A"):** Black-box reuse. Assembles behaviors via encapsulated instance components. Dynamically interchangeable at runtime via dependency interfaces.

```cpp
// INHERITANCE APPROACH (Tightly Coupled)
class ArrayStack : public std::vector<int> {
    // Exposes unwanted vector methods like insert(), clear(), erase()
};

// COMPOSITION APPROACH (Decoupled & Clean Interface)
class Stack {
private:
    std::vector<int> storage; // Encapsulated internal implementation
public:
    void push(int val) { storage.push_back(val); }
    void pop() { storage.pop_back(); }
};
```

---

# 14. Overloading vs Overriding vs Hiding

🔴 **High Priority / Frequently Tested**

| Feature | Overloading | Overriding | Hiding (Name Hiding) |
| :--- | :--- | :--- | :--- |
| **Scope** | Same class scope. | Base vs Derived class. | Base vs Derived class. |
| **Parameters** | Must differ. | Must match exactly. | Can match or differ. |
| **`virtual` Needed?**| No. | **Yes** (in Base). | **No**. |
| **Binding** | Compile-time. | Runtime (Dynamic). | Compile-time. |
| **Return Type** | Can match or differ (cannot differ *only* by return type). | Must match (or covariant pointer/ref). | Irrelevant. |

### Function Name Hiding Example
In C++, if a derived class declares a function with the **same name** as a base class function, it **hides all overloads** of that function name in the base class scope, regardless of parameter signatures!

```cpp
class Base {
public:
    void display() { std::cout << "Base::display()\n"; }
    void display(int i) { std::cout << "Base::display(int)\n"; }
};

class Derived : public Base {
public:
    // Hides BOTH Base::display() and Base::display(int)!
    void display(std::string s) { std::cout << "Derived::display(string)\n"; }
};

int main() {
    Derived d;
    // d.display(10); // COMPILE ERROR! Base::display(int) is hidden!
    
    // FIX: Bring base names into scope inside derived class:
    // using Base::display;
}
```

---

# 15. Virtual Destructors

🔴 **High Priority / Frequently Tested**

⭐ **Interview Trap:** What happens if you delete a derived object through a base pointer with a non-virtual destructor?

```cpp
class Base {
public:
    ~Base() { std::cout << "Base Destructor\n"; } // NON-VIRTUAL DESTRUCTOR!
};

class Derived : public Base {
    int* heap_array;
public:
    Derived() : heap_array(new int[100]) {}
    ~Derived() { 
        delete[] heap_array; 
        std::cout << "Derived Destructor\n"; 
    }
};

int main() {
    Base* ptr = new Derived();
    delete ptr; // UNDEFINED BEHAVIOR! Only ~Base() fires. heap_array leaks!
}
```

### The Rule
**Always make base class destructors `virtual` if the class has any virtual functions or is intended to be used polymorphically via base pointers.**

```cpp
class Base {
public:
    virtual ~Base() = default; // Guaranteed dynamic cleanup dispatch
};
```

---

# 16. Multiple Inheritance & The Diamond Problem

🔴 **High Priority / Frequently Tested**

```
       Animal
      /      \
  Mammal    WingedAnimal
      \      /
         Bat
```

When a derived class (`Bat`) inherits via multiple paths from a common ancestor (`Animal`), it duplicates base instance data members, creating member access ambiguities.

## Virtual Inheritance Solution
Virtual inheritance (`virtual public`) ensures that only **one shared instance** of the base class exists within the object hierarchy.

```cpp
class Animal {
public:
    int age;
};

// Virtual base inheritance
class Mammal : virtual public Animal {};
class WingedAnimal : virtual public Animal {};

class Bat : public Mammal, public WingedAnimal {};

int main() {
    Bat bat;
    bat.age = 5; // OK! No ambiguity because Animal is shared.
}
```

---

# 17. Object Slicing

🟡 **Important**

Object slicing occurs when a derived class instance is assigned to a base class instance **by value**. The derived portion of the object is stripped ("sliced") away, leaving only the base slice.

```cpp
class Base { public: int x = 1; };
class Derived : public Base { public: int y = 2; };

void printBase(Base b) { // Pass BY VALUE causes slicing!
    std::cout << b.x;
}

int main() {
    Derived d;
    Base b = d; // SLICING! Derived 'y' data and vtable lost.
    
    // PREVENT SLICING: Pass by pointer or reference:
    // void printBase(const Base& b);
}
```

---

# 18. Casting Mechanics (Upcasting, Downcasting, RTTI)

🔴 **High Priority / Frequently Tested**

```cpp
class Base { public: virtual ~Base() = default; };
class Derived : public Base { public: void derivedOnlyMethod() {} };
```

* **Upcasting:** Converting derived pointer/reference to base pointer/reference. **Always safe and implicit.**
* **Downcasting:** Converting base pointer/reference to derived pointer/reference. Potentially unsafe. Requires explicit cast.

```cpp
Base* basePtr = new Derived();

// 1. static_cast (Compile-time downcast, no runtime validation)
// Fast, but if basePtr is NOT actually a Derived object -> Undefined Behavior!
Derived* d1 = static_cast<Derived*>(basePtr); 

// 2. dynamic_cast (Runtime Type Information - RTTI check)
// Checks vtable type info. Returns nullptr if cast fails (or throws std::bad_cast for references).
Derived* d2 = dynamic_cast<Derived*>(basePtr);
if (d2) {
    d2->derivedOnlyMethod();
}
```

---

# 19. Operator Overloading

🟡 **Important**

Operator overloading allows user types to define custom semantics for C++ operators.

```cpp
class Complex {
    double real, imag;
public:
    Complex(double r, double i) : real(r), imag(i) {}

    // Binary + Operator (Member function)
    Complex operator+(const Complex& rhs) const {
        return Complex(real + rhs.real, imag + rhs.imag);
    }

    // Friend stream insertion operator (Non-member required!)
    // Must be non-member because left operand is std::ostream, not Complex!
    friend std::ostream& operator<<(std::ostream& os, const Complex& c) {
        os << c.real << "+" << c.imag << "i";
        return os;
    }
};
```

⭐ **Interview Trap:** Operators that CANNOT be overloaded:
1. Scope Resolution (`::`)
2. Ternary Conditional (`?:`)
3. Member Access (`.`)
4. Pointer-to-member (`.*`)
5. `sizeof` / `typeid`

---

# 20. Const Correctness in OOP

🟡 **Important**

A `const` member function guarantees that it will not modify any non-mutable data members of the class, allowing it to be invoked on `const` object instances.

```cpp
class Account {
    double balance;
    mutable int access_count = 0; // 'mutable' allows modifications inside const functions!

public:
    double getBalance() const { 
        access_count++; // Legal because of 'mutable' keyword
        // balance += 10; // COMPILE ERROR! Modifying non-mutable member in const function
        return balance; 
    }
};
```

---

# 21. `struct` vs `class` in C++

🟢 **Fundamental**

| Feature | `class` | `struct` |
| :--- | :--- | :--- |
| Default Member Access | `private` | `public` |
| Default Inheritance Access | `private` | `public` |
| Technical Capabilities | Identical (can have constructors, virtual functions, templates). | Identical. |
| Idiomatic Usage | Encapsulated domain entities with private state and invariants. | Plain Old Data (POD) / Passive Data Structures with no complex invariants. |

---

# 22. SOLID Principles

🔴 **High Priority / Frequently Tested**

```
S — Single Responsibility Principle (SRP)
O — Open/Closed Principle (OCP)
L — Liskov Substitution Principle (LSP)
I — Interface Segregation Principle (ISP)
D — Dependency Inversion Principle (DIP)
```

## 22.1 S — Single Responsibility Principle (SRP)
* **Definition:** A class should have one, and only one, reason to change.
* **Bad:** `UserAccount` managing validation, database persistence, and sending email notifications.
* **Good:** Separate `UserAccount`, `UserRepository` (persistence), and `EmailService`.

## 22.2 O — Open/Closed Principle (OCP)
* **Definition:** Software entities should be open for extension, but closed for modification.
* **Bad:** Using `switch(type)` statements over enum shapes inside `AreaCalculator`. Adding a shape modifies core calculator logic.
* **Good:** Shape abstraction with `virtual double area() const = 0;`. Adding new shapes requires zero edits to existing calculator code.

## 22.3 L — Liskov Substitution Principle (LSP)
* **Definition:** Derived types must be completely substitutable for their base types without altering program correctness.
* **Bad:** `Square` inheriting from `Rectangle`. Setting width on `Square` implicitly mutates height, violating callers' invariants for `Rectangle`.
* **Good:** Separate `Shape` hierarchy or decoupled types without improper subtype constraints.

## 22.4 I — Interface Segregation Principle (ISP)
* **Definition:** Clients should not be forced to depend on interfaces they do not use.
* **Bad:** A bloated `IMultiFunctionPrinter` forcing a `BasicPrinter` class to implement dummy `fax()` and `scan()` throwing exceptions.
* **Good:** Split into `IPrinter`, `IScanner`, `IFax`.

## 22.5 D — Dependency Inversion Principle (DIP)
* **Definition:** High-level modules should not depend on low-level modules; both should depend on abstractions.
* **Bad:** `Car` directly constructing a concrete `V8Engine` instance (`engine = new V8Engine()`).
* **Good:** `Car` accepting an `IEngine` interface reference via constructor injection.

---

# 23. Dependency Injection, Coupling & Cohesion

🟡 **Important**

* **High Cohesion:** The degree to which elements inside a class belong together logically. **Goal: High Cohesion.**
* **Low Coupling:** The degree of interdependence between software modules. **Goal: Low Coupling.**
* **Dependency Injection (DI):** Passing dependent objects into a class constructor or setter rather than letting the class instantiate dependencies directly.

```cpp
// Constructor Dependency Injection
class NotificationManager {
    std::shared_ptr<IMessageService> service;
public:
    // Injected abstract dependency
    explicit NotificationManager(std::shared_ptr<IMessageService> s) : service(std::move(s)) {}
    
    void send(const std::string& msg) { service->sendMessage(msg); }
};
```

---

# 24. Immutability & Thread Safety

🟡 **Important**

An **immutable object** cannot be modified after construction.
* **Benefits:** Inherently thread-safe without mutex locks; no race conditions; state invalidation impossible.
* **C++ Pattern:** Mark data members `const`, omit setters, pass references to `const`.

---

# 25. Object Relationships Summary

| Term | Category | Description |
| :--- | :--- | :--- |
| **`is-a`** | Inheritance | `Dog` is an `Animal`. |
| **`has-a`** | Aggregation / Composition | `Car` has a `Wheel`. |
| **`uses-a`** | Association | `Printer` uses a `Document`. |

---

# 26. Memory Management & RAII

🔴 **High Priority / Frequently Tested**

> [!IMPORTANT]
> **RAII (Resource Acquisition Is Initialization)** is the core software idiom of modern C++ OOP.

**RAII Principle:** Bind resource lifecycle (heap memory, file handles, sockets, mutex locks) to object lifetime. Acquire resources in the constructor; release them automatically in the destructor.

```cpp
// RAII Mutex Lock Guard Example
class LockGuard {
    std::mutex& mtx;
public:
    explicit LockGuard(std::mutex& m) : mtx(m) { mtx.lock(); }
    ~LockGuard() { mtx.unlock(); } // Auto-release when going out of scope!
};
```

---

# 27. Smart Pointers & OOP

🔴 **High Priority / Frequently Tested**

Smart pointers automate memory management using RAII to wrap raw heap pointers.

* **`std::unique_ptr<T>`:** Exclusive ownership model. Non-copyable, move-only.
* **`std::shared_ptr<T>`:** Shared reference-counted ownership. Memory freed when reference count hits zero.
* **`std::weak_ptr<T>`:** Non-owning reference. Used to break reference cycles in shared-pointer graphs.

### Polymorphism with Smart Pointers
```cpp
#include <memory>
#include <vector>

class Shape { public: virtual void draw() = 0; virtual ~Shape() = default; };
class Circle : public Shape { public: void draw() override {} };

int main() {
    // Polymorphic container of unique pointers
    std::vector<std::unique_ptr<Shape>> shapes;
    shapes.push_back(std::make_unique<Circle>());
    shapes[0]->draw(); // Polymorphic invocation
}
```

---

# 28. SOLID & OOP System Design Interview Framework

When asked to design a system (e.g., *Parking Lot*, *Elevator*, *Logging System*) in a Microsoft OOP interview:

```
1. Clarify Requirements ──► 2. Define Entities ──► 3. Map Relationships ──► 4. Apply SOLID & Patterns
```

### Key Questions Overview
* **Parking Lot:** Focus on spot abstraction (`ParkingSpot`), pricing strategy interfaces (`IPricingStrategy`), and enum vehicle categorization (`VehicleType`).
* **Elevator System:** Focus on state machine design (`ElevatorState`), request dispatching algorithm strategy (`IDispatchStrategy`), and observer pattern for floor displays.
* **Payment / Notification System:** Focus on Strategy Pattern (interchangeable gateways/channels) and Factory Pattern for instance creation.

---

# 29. 50 Microsoft-Style OOP Interview Questions

### Beginner (🟢)
1. **What is OOP, and how does it differ from procedural programming?**
   * *Answer:* Procedural organizes code into linear functions acting on exposed global/local data. OOP encapsulates data state and functions into unified objects, protecting invariants.
2. **What is a class and an object?**
   * *Answer:* A class is a structural blueprint/type; an object is a concrete, instantiated memory region with state, behavior, and address identity.
3. **What are the default access specifiers for `class` and `struct` in C++?**
   * *Answer:* `class` defaults to `private`; `struct` defaults to `public`.
4. **What is encapsulation?**
   * *Answer:* Grouping data and methods while restricting direct state access via access specifiers.
5. **What is the difference between data hiding and encapsulation?**
   * *Answer:* Encapsulation is the grouping structural mechanism; data hiding is the accessibility restriction policy (`private`).
6. **What is function overloading?**
   * *Answer:* Multiple functions sharing a name within the same scope differentiated by parameter types/counts.
7. **Can return types distinguish function overloads in C++?**
   * *Answer:* No. Return type alone is insufficient for overload resolution.
8. **What is a constructor?**
   * *Answer:* A special member function initializing an instance upon memory allocation.
9. **What is a default constructor?**
   * *Answer:* A constructor callable with zero arguments.
10. **What is a copy constructor?**
    * *Answer:* A constructor initializing an object using another instance of the same class (`T(const T&)`).
11. **What is the `this` pointer?**
    * *Answer:* An implicit pointer parameter pointing to the invoking instance inside non-static member methods.
12. **What is `public` inheritance?**
    * *Answer:* Inheritance where base public/protected members retain their accessibility in derived scopes.
13. **What is the difference between stack and heap memory allocation?**
    * *Answer:* Stack memory is automatic and scoped; heap memory is explicit free-store managed via `new`/`delete`.
14. **What is an abstract class?**
    * *Answer:* A class containing at least one pure virtual function (`= 0`). Cannot be instantiated.
15. **What is a pure virtual function?**
    * *Answer:* A function declaration marked `= 0` that derived classes must override to become concrete.

### Intermediate (🟡)
16. **Explain the difference between compile-time and runtime polymorphism.**
    * *Answer:* Compile-time uses signatures/templates resolved statically. Runtime uses virtual methods dispatched dynamically via vtables.
17. **What is dynamic dispatch?**
    * *Answer:* Deciding which overridden virtual function implementation to invoke at runtime based on object type.
18. **How does `vptr` work in C++?**
    * *Answer:* A hidden pointer member inserted by the compiler pointing to the class's `vtable` virtual function addresses.
19. **What is the performance overhead of virtual functions?**
    * *Answer:* Dereference pointer lookup cost, disabled compiler code inlining, +8 bytes object memory overhead.
20. **Why are destructors marked `virtual` in base classes?**
    * *Answer:* To ensure derived destructors execute when deleting derived objects via base class pointers.
21. **What is object slicing?**
    * *Answer:* Copying a derived object to a base object by value, stripping away derived members and virtual bindings.
22. **What is the difference between shallow copy and deep copy?**
    * *Answer:* Shallow copies pointer address memory; deep copies allocate fresh memory and duplicate content.
23. **Explain the Rule of 3.**
    * *Answer:* If managing raw resources, explicitly implement Destructor, Copy Constructor, and Copy Assignment.
24. **Explain the Rule of 5.**
    * *Answer:* Extends Rule of 3 to C++11 by adding Move Constructor and Move Assignment.
25. **Explain the Rule of 0.**
    * *Answer:* Delegate memory management to RAII handles (`std::unique_ptr`, `vector`) so zero custom destructors/copy functions are needed.
26. **What does `explicit` do on constructors?**
    * *Answer:* Disables implicit single-argument type conversion during function call parameter passing.
27. **What are static member functions, and why can't they access `this`?**
    * *Answer:* Class-scoped functions without an instance pointer; they execute without an instantiated object.
28. **Explain function hiding in inheritance.**
    * *Answer:* A derived member function name hides all base function overloads of the same name unless re-imported via `using`.
29. **What is multiple inheritance, and what is the Diamond Problem?**
    * *Answer:* Inheriting from multiple classes. Duplicate ancestor base instances cause ambiguity.
30. **How does `virtual public` inheritance solve the Diamond Problem?**
    * *Answer:* Ensures only a single shared instance of the common base class exists in the object memory layout.
31. **What is composition, and why is it preferred over inheritance?**
    * *Answer:* Building features by combining component instances ("has-a"). Offers loose coupling and flexible runtime behavior.
32. **Explain Aggregation vs Composition.**
    * *Answer:* Composition = strong ownership (co-dependent lifetimes). Aggregation = weak ownership (independent lifetimes).
33. **What is RAII?**
    * *Answer:* Tying resource allocation/cleanup strictly to stack object lifetime constructors and destructors.
34. **What is a friend function, and does it break encapsulation?**
    * *Answer:* Non-member granted private access. Violates strict visibility boundaries, but useful for stream operator overloads.
35. **What is `const` correctness?**
    * *Answer:* Marking methods `const` to guarantee state immutability, enabling safe calls on `const` references.

### Advanced (🔴)
36. **Explain move semantics and `std::move`.**
    * *Answer:* Transferring ownership of underlying resource pointers from rvalues without deep allocation. `std::move` casts an lvalue to an rvalue reference.
37. **What is the purpose of `std::weak_ptr`?**
    * *Answer:* Non-owning observer smart pointer preventing cyclic reference memory leaks in `std::shared_ptr` graphs.
38. **How does `dynamic_cast` work internally?**
    * *Answer:* Inspects RTTI metadata located inside the object's `vtable` to validate base-to-derived type hierarchy compatibility at runtime.
39. **What is Covariant Return Type in method overriding?**
    * *Answer:* An overridden virtual method in a derived class can return a pointer/reference to a type derived from the base method's return type.
40. **Explain the Liskov Substitution Principle (LSP).**
    * *Answer:* Subtypes must fulfill base contracts without breaking expectations (e.g., throwing unexpected exceptions or invalidating invariants).
41. **Explain the Dependency Inversion Principle (DIP).**
    * *Answer:* High-level code depends on abstract interfaces, not concrete implementations.
42. **Can a constructor be `virtual` in C++?**
    * *Answer:* **No.** Dynamic dispatch requires a `vptr` pointing to a `vtable`, which is initialized *by* the constructor.
43. **Can a pure virtual function have a definition body in C++?**
    * *Answer:* **Yes**, but it must be defined outside the class body. Derived classes must still explicitly override it.
44. **What is the difference between `override` and `final`?**
    * *Answer:* `override` enforces signature matching against a base virtual function; `final` halts downstream overriding or inheritance.
45. **What is placement `new`?**
    * *Answer:* Constructs an object inside a pre-allocated buffer address (`new (buffer) Type()`).

### Tricky / Traps (⭐)
46. **What happens if an exception is thrown inside a constructor?**
    * *Answer:* Destructor for the current object will *not* fire! Only fully constructed sub-objects/members get destroyed. Memory leaks occur unless smart pointers/RAII are used.
47. **Why shouldn't you call virtual functions inside constructors or destructors?**
    * *Answer:* Dynamic dispatch is disabled! During construction/destruction, the object `vptr` points to the *currently executing base level*, not the derived level.
48. **Is private inheritance the same as composition?**
    * *Answer:* Semantically similar ("implemented-in-terms-of"), but private inheritance grants access to protected members and virtual overrides. Prefer composition!
49. **Does an empty class in C++ take 0 bytes of memory?**
    * *Answer:* **No.** Size is at least 1 byte to guarantee unique addresses for distinct instances.
50. **What is the Empty Base Optimization (EBO)?**
    * *Answer:* Compilers allocate 0 bytes for empty base classes inside a derived class memory layout, avoiding the 1-byte penalty.

---

# 30. 20 C++ Output-Based OOP Snippets

### Snippet 1: Non-Virtual Method Call
```cpp
#include <iostream>
class A { public: void show() { std::cout << "A"; } };
class B : public A { public: void show() { std::cout << "B"; } };
int main() { A* p = new B(); p->show(); delete p; }
```
* **Output:** `A`
* **Why:** `show()` is non-virtual. Binding resolved statically based on pointer type (`A*`).

---

### Snippet 2: Virtual Method Overriding
```cpp
#include <iostream>
class A { public: virtual void show() { std::cout << "A"; } };
class B : public A { public: void show() override { std::cout << "B"; } };
int main() { A* p = new B(); p->show(); delete p; }
```
* **Output:** `B`
* **Why:** `show()` is virtual. Dynamic dispatch resolves output via `B`'s `vtable`.

---

### Snippet 3: Constructor Invocation Order
```cpp
#include <iostream>
class A { public: A() { std::cout << "A"; } };
class B : public A { public: B() { std::cout << "B"; } };
int main() { B b; }
```
* **Output:** `AB`
* **Why:** Base constructor `A()` executes prior to derived constructor `B()` body.

---

### Snippet 4: Destructor Execution Order
```cpp
#include <iostream>
class A { public: ~A() { std::cout << "A"; } };
class B : public A { public: ~B() { std::cout << "B"; } };
int main() { B b; }
```
* **Output:** `BA`
* **Why:** Destructors fire in exact reverse construction order.

---

### Snippet 5: Missing Virtual Destructor Leak
```cpp
#include <iostream>
class A { public: ~A() { std::cout << "A"; } };
class B : public A { public: ~B() { std::cout << "B"; } };
int main() { A* p = new B(); delete p; }
```
* **Output:** `A`
* **Why:** `~A()` is non-virtual. `delete p` invokes only `~A()`, causing undefined behavior and skipping `~B()`.

---

### Snippet 6: Function Name Hiding
```cpp
#include <iostream>
class Base { public: void print(int) { std::cout << "Int"; } };
class Derived : public Base { public: void print(double) { std::cout << "Double"; } };
int main() { Derived d; d.print(5); }
```
* **Output:** `Double`
* **Why:** `Derived::print(double)` hides `Base::print(int)`. The `5` converts to `double`.

---

### Snippet 7: Object Slicing
```cpp
#include <iostream>
class Base { public: virtual void print() { std::cout << "Base"; } };
class Derived : public Base { public: void print() override { std::cout << "Derived"; } };
void call(Base b) { b.print(); }
int main() { Derived d; call(d); }
```
* **Output:** `Base`
* **Why:** Pass-by-value slices `Derived d` into a pure `Base` instance, losing `vtable` dynamic dispatch.

---

### Snippet 8: Virtual Call Inside Constructor
```cpp
#include <iostream>
class Base {
public:
    Base() { foo(); }
    virtual void foo() { std::cout << "BaseFoo "; }
};
class Derived : public Base {
public:
    void foo() override { std::cout << "DerivedFoo "; }
};
int main() { Derived d; }
```
* **Output:** `BaseFoo `
* **Why:** Dynamic dispatch is turned off during base construction. Object is not yet a `Derived`.

---

### Snippet 9: Default Parameter Values in Virtual Functions
```cpp
#include <iostream>
class Base {
public:
    virtual void print(int val = 10) { std::cout << "Base:" << val; }
};
class Derived : public Base {
public:
    void print(int val = 20) override { std::cout << "Derived:" << val; }
};
int main() {
    Base* b = new Derived();
    b->print();
    delete b;
}
```
* **Output:** `Derived:10`
* **Why:** **TRICKY!** Virtual function implementation resolved dynamically (`Derived`), but **default parameter values are bound statically** at compile time based on pointer type (`Base`).

---

### Snippet 10: Private Inheritance Accessibility
```cpp
#include <iostream>
class A { public: int x = 5; };
class B : private A {};
int main() { 
    B b; 
    // std::cout << b.x; 
}
```
* **Output:** `Compile Error`
* **Why:** Private inheritance renders public base members `private` in `B`.

---

### Snippet 11: Static Data Member Lifetime
```cpp
#include <iostream>
class Test {
public:
    static int count;
    Test() { count++; }
};
int Test::count = 0;
int main() { Test a, b, c; std::cout << Test::count; }
```
* **Output:** `3`
* **Why:** `count` is shared across all instances.

---

### Snippet 12: Diamond Inheritance Without Virtual Keyword
```cpp
#include <iostream>
class A { public: int val = 42; };
class B : public A {};
class C : public A {};
class D : public B, public C {};
int main() {
    D d;
    // std::cout << d.val;
}
```
* **Output:** `Compile Error`
* **Why:** Ambiguous member access. `d` contains two instances of `A` (`B::A` and `C::A`).

---

### Snippet 13: Static Method Scope Access
```cpp
#include <iostream>
class Item {
    int price = 100;
public:
    static void print() {
        // std::cout << price;
    }
};
```
* **Output:** `Compile Error`
* **Why:** Static member functions lack a `this` pointer and cannot access instance members (`price`).

---

### Snippet 14: Dynamic Cast Failure on Pointer
```cpp
#include <iostream>
class A { public: virtual ~A() = default; };
class B : public A {};
class C : public A {};
int main() {
    A* a = new B();
    C* c = dynamic_cast<C*>(a);
    std::cout << (c == nullptr ? "Null" : "Valid");
    delete a;
}
```
* **Output:** `Null`
* **Why:** `a` points to a `B` instance. Downcasting to unrelated `C*` via `dynamic_cast` fails and yields `nullptr`.

---

### Snippet 15: Friend Function Accessing Privates
```cpp
#include <iostream>
class Box {
    int width = 10;
    friend void printWidth(Box b);
};
void printWidth(Box b) { std::cout << b.width; }
int main() { Box b; printWidth(b); }
```
* **Output:** `10`
* **Why:** `friend` function declaration grants non-member `printWidth` access to private members.

---

### Snippet 16: Size of Empty Class
```cpp
#include <iostream>
class Empty {};
int main() { std::cout << (sizeof(Empty) >= 1); }
```
* **Output:** `1` (True)
* **Why:** C++ mandates empty objects occupy at least 1 byte to ensure distinct addresses.

---

### Snippet 17: Copy Constructor vs Assignment Operator
```cpp
#include <iostream>
class Dummy {
public:
    Dummy() { std::cout << "C"; }
    Dummy(const Dummy&) { std::cout << "Copy"; }
    Dummy& operator=(const Dummy&) { std::cout << "Assign"; return *this; }
};
int main() {
    Dummy d1;
    Dummy d2 = d1; // Initializing new object
}
```
* **Output:** `CCopy`
* **Why:** `Dummy d2 = d1;` calls the **Copy Constructor**, *not* the assignment operator, because `d2` is being constructed!

---

### Snippet 18: Assignment Operator Executing
```cpp
#include <iostream>
class Dummy {
public:
    Dummy() { std::cout << "C"; }
    Dummy& operator=(const Dummy&) { std::cout << "Assign"; return *this; }
};
int main() {
    Dummy d1, d2;
    d2 = d1; // Already constructed object
}
```
* **Output:** `CCAssign`
* **Why:** Both objects already exist; `d2 = d1` invokes `operator=`.

---

### Snippet 19: Const Member Function Overloading
```cpp
#include <iostream>
class Test {
public:
    void run() { std::cout << "Non-Const "; }
    void run() const { std::cout << "Const "; }
};
int main() {
    Test t1;
    const Test t2;
    t1.run();
    t2.run();
}
```
* **Output:** `Non-Const Const `
* **Why:** Member methods can be overloaded on `const` qualifiers.

---

### Snippet 20: Overriding Pure Virtual Function with Default Implementation
```cpp
#include <iostream>
class Base {
public:
    virtual void msg() = 0;
    virtual ~Base() = default;
};
void Base::msg() { std::cout << "BaseMsg "; }

class Derived : public Base {
public:
    void msg() override { Base::msg(); std::cout << "DerivedMsg"; }
};

int main() {
    Base* b = new Derived();
    b->msg();
    delete b;
}
```
* **Output:** `BaseMsg DerivedMsg`
* **Why:** Pure virtual functions can have definitions in C++, called explicitly via scope qualification (`Base::msg()`).

---

# 31. Interview Traps

⭐ **Common Candidates Pitfalls**

1. **Believing "OOP = 4 Pillars":** OOP is about architecture, decoupling, object boundaries, and maintaining state invariants.
2. **Confusing Overloading and Overriding:** Overloading happens in the same scope at compile time; overriding happens across derived scopes at runtime using `virtual`.
3. **Omitting Virtual Destructors:** Deleting derived objects via base pointers causes memory leaks if `~Base()` is non-virtual.
4. **Expecting Virtual Dispatch inside Constructors/Destructors:** Objects are constructed base-first; dynamic dispatch resolves to the current executing constructor's base level.
5. **Static Parameter Bindings with Virtual Functions:** Virtual function execution is dynamic, but **default parameter values are resolved statically**.
6. **Failing Self-Assignment in `operator=`:** `if (this == &other) return *this;` is mandatory to prevent deleting internal data before copying.
7. **Assuming `private` Inheritance inherits nothing:** Private base members *are* inherited into memory, but are inaccessible to child code.

---

# 32. OOP Quick Revision & Comparison Tables

### 1. Encapsulation vs Abstraction
| Property | Encapsulation | Abstraction |
| :--- | :--- | :--- |
| **Focus** | Hiding implementation details & state binding. | Exposing high-level interface behavior contracts. |
| **Tool** | `private` / `protected` keywords. | Abstract classes / Pure virtual functions. |

### 2. Overloading vs Overriding
| Property | Overloading | Overriding |
| :--- | :--- | :--- |
| **Binding** | Static (Compile-time). | Dynamic (Runtime via `vtable`). |
| **Scope** | Same class scope. | Base vs Derived classes. |
| **Signature** | Parameters must differ. | Parameters must match exactly. |

### 3. Shallow Copy vs Deep Copy
| Property | Shallow Copy | Deep Copy |
| :--- | :--- | :--- |
| **Memory** | Copies raw pointers directly (shared pointer addresses). | Allocates new memory blocks and duplicates data. |
| **Risk** | Causes double-free errors on destruction. | Performance overhead on large allocations. |

### 4. Struct vs Class
| Property | `struct` | `class` |
| :--- | :--- | :--- |
| **Default Access**| `public` | `private` |
| **Inheritance** | `public` by default. | `private` by default. |

---

# 33. How to Answer OOP Questions in an Interview

### Candidate Answer Framework Structure
1. **Definition:** 1-sentence precise technical summary.
2. **Why it Exists:** The engineering problem it solves.
3. **C++ Mechanics:** Low-level implementation details (`vtable`, `RAII`, `this`).
4. **Trade-offs / Limitations:** Overhead, coupling risks, or pitfalls.
5. **Real-world Example:** Short scenario demonstrating usage.

### Model Answer: "What is Polymorphism and how is it implemented in C++?"

> **Candidate Response:**
> "Polymorphism literally means 'many forms'. In software engineering, it allows a single interface to represent different underlying data types.
>
> We divide polymorphism into two types:
> 1. **Compile-time Polymorphism**, implemented via function overloading and templates. It gives us maximum execution speed because dispatch decisions happen at compile time without runtime indirection.
> 2. **Runtime Polymorphism**, implemented via virtual functions and method overriding. This allows a base class pointer to invoke derived class implementations dynamically.
>
> In C++, runtime polymorphism is typically implemented using a **vtable** and **vptr**. Every class containing virtual functions has a static `vtable` array listing method addresses, and instances store a hidden `vptr` pointing to it. When invoking a virtual method, the program dereferences `vptr` at runtime to find the correct method address.
>
> The main trade-off is performance: virtual dispatch introduces a double-pointer dereference overhead and prevents inline optimizations. Additionally, base classes used polymorphically must declare a `virtual destructor` to avoid memory leaks during cleanup."

---

# 34. If I Have Only 1 Hour

### ⏱️ Priority Revision Checklist (Microsoft Interview)

#### 1. First 15 Minutes: Must-Know Mechanics
* [ ] Review **Virtual Destructors** ([Section 15](#15-virtual-destructors)).
* [ ] Review **vtable / vptr** layout and dynamic dispatch ([Section 4](#4-virtual-functions--deep-dive)).
* [ ] Review **Rule of 0 / 3 / 5** and Deep vs Shallow copy ([Section 6](#6-copy--move-semantics-rule-of-035)).

#### 2. Next 15 Minutes: Design & Patterns
* [ ] Memorize the **SOLID Principles** with C++ examples ([Section 22](#22-solid-principles)).
* [ ] Understand **Inheritance vs Composition** trade-offs ([Section 13](#13-inheritance-vs-composition)).
* [ ] Review **RAII** and **Smart Pointers** ([Section 26](#26-memory-management--raii) & [Section 27](#27-smart-pointers--oop)).

#### 3. Next 15 Minutes: Traps & Code Snippets
* [ ] Practice output snippets for **Virtual calls in Constructors**, **Function Name Hiding**, and **Object Slicing** ([Section 30](#30-20-c-output-based-oop-snippets)).
* [ ] Memorize the **Diamond Problem** and `virtual public` inheritance ([Section 16](#16-multiple-inheritance--the-diamond-problem)).

#### 4. Final 15 Minutes: Mock Question Mental Runs
* [ ] Rehearse the [Interview Answer Framework](#33-how-to-answer-oop-questions-in-an-interview).
* [ ] Quickly scan the [50 Interview Questions](#29-50-microsoft-style-oop-interview-questions) list to verify zero blind spots.
