import { TestBed } from '@angular/core/testing';
import { FriendService } from './friend.service';

describe('FriendService', () => {
  let service: FriendService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(FriendService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('should return predefined friends', () => {
    const friends = service.getFriends();
    expect(friends.length).toBeGreaterThan(0);
  });
});
