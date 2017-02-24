Okay, so what does this need to be able to do?

It needs to be able to recieve (casts):
- New objects to add
- The instruction to remove an object
 - Possibly just remove the object on death?
- Functions to call on its objects
- Requests (any of the above) to pass to its neighbors
(calls):
- Functions to call on its objects
- Requests (any of the above) to pass to its neighbors

It needs to be able to send:
- How many objects it has
- Functions for its objects to call
- Necessary dynamic information to render its objects

It needs to be able to internally check:
- Whether any rules trigger

Thus:
Necessary state:
- List of (tagged) object PIDs
- Conditions for rules (mapped to said rules)

Necessary built-in functions:
- Update object list
- Call function on object
- Cast request to object
- Check object list for rule applicability
- Provide real position of object based on abstract position

Necessary usercode:
- Rules (both conditions and functions)
- Convert abstract to real position
