import {
  act,
  cleanup,
  createEvent,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import { AdminIconAction } from './AdminIconAction';

/**
 * Bu testler ikon şeridinin ASIL RİSKİNİ koruyor: metin kalkınca eylemin
 * adı yalnızca ipucunda ve `aria-label`da kalıyor. İkisinden biri düşerse
 * satırdaki dört ikon, adı olmayan dört şekle dönüşür.
 */

function Icon() {
  return <svg data-testid="icon" />;
}

beforeEach(() => {
  vi.useFakeTimers();
  // "Sıcak pencere" modül düzeyinde tutuluyor ve testler arasında taşınır:
  // taşıdığında, gecikmeyi ölçen test anında açılan bir ipucu görür. Saati
  // pencerenin ötesine atmak her testi soğuk başlatır.
  vi.setSystemTime(Date.now() + 60_000);
});

afterEach(() => {
  // Bu projede otomatik temizlik açık değil (bkz. `src/test/setup.ts`);
  // sökülmeyen bir render bir sonraki testin sorgularını ikiye katlar.
  cleanup();
  vi.useRealTimers();
});

test('eylemin adı ikon üzerinde erişilebilir isim olarak durur', () => {
  render(
    <AdminIconAction label="Pasifleştir" icon={<Icon />} onClick={vi.fn()} />,
  );
  expect(screen.getByRole('button', { name: 'Pasifleştir' })).toBeTruthy();
});

test('fare üzerine gelince ipucu BEKLEME sonrası açılır, ayrılınca kapanır', () => {
  render(
    <AdminIconAction label="Admin yap" icon={<Icon />} onClick={vi.fn()} />,
  );
  const button = screen.getByRole('button', { name: 'Admin yap' });

  fireEvent.pointerEnter(button, { pointerType: 'mouse' });
  // Bekleme dolmadan hiçbir şey görünmemeli: tablonun üzerinden geçen
  // fare her satırda ipucu yakmasın.
  expect(document.querySelector('.admin-tip')).toBeNull();

  act(() => {
    vi.advanceTimersByTime(400);
  });
  expect(document.querySelector('.admin-tip')?.textContent).toBe('Admin yap');

  fireEvent.pointerLeave(button);
  expect(document.querySelector('.admin-tip')).toBeNull();
});

test('dokunmatikte ipucu açılmaz — eylemin kendisiyle yarışmasın', () => {
  render(<AdminIconAction label="Detay" icon={<Icon />} onClick={vi.fn()} />);

  // jsdom `PointerEvent` sınıfını hiç tanımlamıyor; testing-library sade bir
  // `Event` üretiyor ve `pointerType` yolda düşüyor. Özelliği elle tanımlamak
  // tarayıcının gerçekte gönderdiği olayı taklit etmenin tek yolu.
  const event = createEvent.pointerEnter(
    screen.getByRole('button', { name: 'Detay' }),
  );
  Object.defineProperty(event, 'pointerType', { value: 'touch' });
  fireEvent(screen.getByRole('button', { name: 'Detay' }), event);

  act(() => {
    vi.advanceTimersByTime(1000);
  });
  expect(document.querySelector('.admin-tip')).toBeNull();
});

/**
 * En önemli davranış: kendi hesabını pasifleştiremeyen admin, SEBEBİ
 * görebilmeli. Yerel `disabled` özniteliğiyle fare olayı hiç gelmeyeceği
 * için ipucu da açılmaz ve kullanıcı silik bir ikona bakakalırdı.
 */
test('basılamayan düğme sebebi ipucunda gösterir ve tıklamayı yutar', () => {
  const onClick = vi.fn();
  render(
    <AdminIconAction
      label="Pasifleştir"
      icon={<Icon />}
      disabledReason="Kendi hesabının durumunu değiştiremezsin."
      onClick={onClick}
    />,
  );
  const button = screen.getByRole('button', { name: 'Pasifleştir' });

  fireEvent.click(button);
  expect(onClick).not.toHaveBeenCalled();
  expect(button.getAttribute('aria-disabled')).toBe('true');

  fireEvent.pointerEnter(button, { pointerType: 'mouse' });
  act(() => {
    vi.advanceTimersByTime(400);
  });
  expect(document.querySelector('.admin-tip')?.textContent).toBe(
    'Kendi hesabının durumunu değiştiremezsin.',
  );

  // Sebep ipucundan bağımsız olarak da duyurulmalı: ekran okuyucu
  // kullanan biri düğmenin üzerine "gelmez".
  const describedBy = button.getAttribute('aria-describedby');
  expect(describedBy).toBeTruthy();
  expect(document.getElementById(describedBy!)?.textContent).toBe(
    'Kendi hesabının durumunu değiştiremezsin.',
  );
});

test('sayfa kayınca ipucu kapanır — düğmesinden kopmuş olur', () => {
  render(<AdminIconAction label="Detay" icon={<Icon />} onClick={vi.fn()} />);

  fireEvent.pointerEnter(screen.getByRole('button', { name: 'Detay' }), {
    pointerType: 'mouse',
  });
  act(() => {
    vi.advanceTimersByTime(400);
  });
  expect(document.querySelector('.admin-tip')).not.toBeNull();

  act(() => {
    window.dispatchEvent(new Event('scroll'));
  });
  expect(document.querySelector('.admin-tip')).toBeNull();
});
