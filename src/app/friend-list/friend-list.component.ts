import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Friend } from '../models/friend.interface';
import { FriendService } from '../friend.service';

@Component({
  selector: 'app-friend-list',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './friend-list.component.html',
  styleUrls: ['./friend-list.component.css'],
})
export class FriendListComponent implements OnInit {
  friends: Friend[] = [];

  constructor(private friendService: FriendService) {}

  ngOnInit(): void {
    this.getFriends();
  }

  getFriends(): void {
    // Retrieve friends from the service and assign to local state
    this.friends = this.friendService.getFriends();
  }
}
