import { Injectable } from '@angular/core';
import { Friend } from './models/friend.interface';
import { FRIENDS } from '../data/mock_data';

@Injectable({
  providedIn: 'root',
})
export class FriendService {
  private friends: Friend[] = FRIENDS;

  constructor(){}

  getFriends(): Friend[] {
    return this.friends;
  }

  addFriend(friend:Friend){}
  updateFriend(friend:Friend){}
  deleteFriend(friendId:number){}

}
