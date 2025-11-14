import { Friend } from "../app/models/friend.interface";

export const FRIENDS: Friend[] = [
  {
    id: 1,
    friendName: "Will",
    phoneNumbers: [
      { id: 101, type: "mobile", "number": "123-456-7890" },
      { id: 102, type: "home", "number": "098-765-4321" }
    ]
  },{
    id: 2,
    friendName: "Jane",
    phoneNumbers: [
      { id: 201, type: "work", "number": "555-555-5555" }
    ]
  },
  {
    id: 3,
    friendName: "Unknown Caller",
    phoneNumbers: [
      { id: 301, type: "work", "number": "885-555-5555" }
    ]
  }
]
