import { Component, signal } from '@angular/core';
import { RouterOutlet, RouterLink } from '@angular/router';
import { CommonModule } from '@angular/common';


@Component({
  selector: 'app-root',
  imports: [CommonModule, RouterOutlet, RouterLink],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class App {
  protected readonly title = signal('friends-app');
  menuOpen = signal(false);
  // Avoid using `new Date()` directly in the template (Angular disallows `new` in template expressions)
  readonly currentYear = new Date().getFullYear();

  toggleMenu(): void {
    this.menuOpen.set(!this.menuOpen());
  }
  closeMenu(): void {
    this.menuOpen.set(false);
  }
}
