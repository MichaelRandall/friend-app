import { ComponentFixture, TestBed } from '@angular/core/testing';

import { FriendForm } from './friend-form';

describe('FriendForm', () => {
  let component: FriendForm;
  let fixture: ComponentFixture<FriendForm>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FriendForm]
    })
    .compileComponents();

    fixture = TestBed.createComponent(FriendForm);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
